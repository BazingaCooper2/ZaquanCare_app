import 'dart:async';
import 'dart:math';
import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:geolocator/geolocator.dart';
import 'package:geocoding/geocoding.dart';
import 'package:intl/intl.dart';
import '../main.dart';
import '../models/employee.dart';
import 'package:nurse_tracking_app/services/session.dart';

class TimeTrackingPage extends StatefulWidget {
  final Employee employee;
  final String? scheduleId;

  const TimeTrackingPage({super.key, required this.employee, this.scheduleId});

  @override
  State<TimeTrackingPage> createState() => _TimeTrackingPageState();
}

class _TimeTrackingPageState extends State<TimeTrackingPage> {
  // Location and tracking state
  Position? _currentPosition;
  String? _currentAddress;
  Timer? _locationTimer;
  StreamSubscription<Position>? _positionSubscription;

  // Clock-in/out state
  bool _isClockedIn = false;
  String? _currentPlaceName;
  String? _currentLogId;
  DateTime? _clockInTimeUtc;

  // Map state
  GoogleMapController? _mapController;
  final Set<Marker> _markers = {};
  final Set<Circle> _circles = {};

  // Assisted-Living locations with 50m geofence
  static const Map<String, LatLng> _locations = {
    'Willow Place': LatLng(43.538165, -80.311467),
    '85 Neeve': LatLng(43.536884, -80.307129),
    '87 Neeve': LatLng(43.536732, -80.307545),
  };

  static const double _geofenceRadius = 50.0; // meters

  @override
  void initState() {
    super.initState();
    _requestLocationPermission();
    _setupMapMarkersAndCircles();
  }

  @override
  void dispose() {
    _locationTimer?.cancel();
    _positionSubscription?.cancel();
    _mapController?.dispose();
    super.dispose();
  }

  Future<void> _requestLocationPermission() async {
    final permission = await Geolocator.checkPermission();

    if (permission == LocationPermission.denied) {
      final requestPermission = await Geolocator.requestPermission();
      if (requestPermission == LocationPermission.denied) {
        _showSnackBar('Location permission denied', isError: true);
        return;
      }
    }

    if (permission == LocationPermission.deniedForever) {
      _showSnackBar(
          'Location permission denied forever. Please enable in settings.',
          isError: true);
      return;
    }

    _startLocationPolling();
  }

  void _startLocationPolling() {
    // Poll GPS every 10 seconds
    _locationTimer = Timer.periodic(const Duration(seconds: 10), (timer) async {
      await _updateLocation();
    });

    // Initial location update
    _updateLocation();
  }

  Future<void> _updateLocation() async {
    try {
      final position = await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.high,
      );

      setState(() {
        _currentPosition = position;
      });

      // Update address if not already set
      _currentAddress ??= await _reverseGeocode(position.latitude, position.longitude);

      // Check for geofence entry
      await _checkGeofenceEntry(position);

      // Update map markers
      _updateMapMarkers();
    } catch (e) {
      _showSnackBar('Location error: $e', isError: true);
    }
  }

  Future<void> _checkGeofenceEntry(Position position) async {
    if (_isClockedIn) return; // Already clocked in

    for (final entry in _locations.entries) {
      final placeName = entry.key;
      final location = entry.value;

      final distance = _calculateDistance(
        position.latitude,
        position.longitude,
        location.latitude,
        location.longitude,
      );

      if (distance <= _geofenceRadius) {
        await _autoClockIn(placeName, position);
        break; // Only clock in to the first location found
      }
    }
  }

  Future<void> _autoClockIn(String placeName, Position position) async {
    try {
      final nowUtc = DateTime.now().toUtc();
      final clockInAddress =
          await _reverseGeocode(position.latitude, position.longitude);

      // Round coordinates to 8 decimal places
      final lat = double.parse(position.latitude.toStringAsFixed(8));
      final lng = double.parse(position.longitude.toStringAsFixed(8));

      final empId = await SessionManager.getEmpId();
      if (empId == null) {
        _showSnackBar('Session expired. Please login again.', isError: true);
        return;
      }

      final response = await supabase.from('time_logs').insert({
        'emp_id': empId,
        'schedule_id': widget.scheduleId,
        'clock_in_time': nowUtc.toIso8601String(),
        'clock_in_latitude': lat,
        'clock_in_longitude': lng,
        'clock_in_address': clockInAddress,
        'updated_at': nowUtc.toIso8601String(),
      }).select('id');

      if (response.isNotEmpty) {
        setState(() {
          _isClockedIn = true;
          _currentPlaceName = placeName;
          _currentLogId = response.first['id'];
          _clockInTimeUtc = nowUtc;
        });

        final localTime = DateFormat('HH:mm:ss').format(DateTime.now());
        _showSnackBar('Clocked in at $placeName ($localTime)');
      }
    } catch (e) {
      _showSnackBar('Error clocking in: $e', isError: true);
    }
  }

  Future<void> _manualClockOut() async {
    if (!_isClockedIn || _currentLogId == null || _currentPosition == null) {
      return;
    }

    try {
      final nowUtc = DateTime.now().toUtc();
      final clockOutAddress = await _reverseGeocode(
          _currentPosition!.latitude, _currentPosition!.longitude);

      // Calculate total hours
      final totalHours = _clockInTimeUtc != null
          ? ((nowUtc.difference(_clockInTimeUtc!).inMinutes) / 60.0)
          : 0.0;

      // Round coordinates to 8 decimal places
      final lat = double.parse(_currentPosition!.latitude.toStringAsFixed(8));
      final lng = double.parse(_currentPosition!.longitude.toStringAsFixed(8));

      final empId = await SessionManager.getEmpId();
      if (empId == null) {
        _showSnackBar('Session expired. Please login again.', isError: true);
        return;
      }

      final update = supabase.from('time_logs').update({
        'clock_out_time': nowUtc.toIso8601String(),
        'clock_out_latitude': lat,
        'clock_out_longitude': lng,
        'clock_out_address': clockOutAddress,
        'total_hours': double.parse(totalHours.toStringAsFixed(2)),
        'updated_at': nowUtc.toIso8601String(),
      });

      if (widget.scheduleId != null) {
        await update.eq('emp_id', empId).eq('schedule_id', widget.scheduleId!);
      } else if (_currentLogId != null) {
        await update.eq('id', _currentLogId!);
      } else {
        _showSnackBar('Unable to find the current log to update.', isError: true);
        return;
      }

      final placeName = _currentPlaceName ?? 'Unknown';
      _showSnackBar(
          'Clocked out. Worked ${totalHours.toStringAsFixed(2)} h at $placeName');

      setState(() {
        _isClockedIn = false;
        _currentLogId = null;
        _currentPlaceName = null;
        _clockInTimeUtc = null;
      });
    } catch (e) {
      _showSnackBar('Error clocking out: $e', isError: true);
    }
  }

  void _setupMapMarkersAndCircles() {
    _markers.clear();
    _circles.clear();

    // Add markers and circles for each location
    for (final entry in _locations.entries) {
      final placeName = entry.key;
      final location = entry.value;

      // Add marker
      _markers.add(
        Marker(
          markerId: MarkerId(placeName),
          position: location,
          infoWindow: InfoWindow(title: placeName),
          icon: BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueRed),
        ),
      );

      // Add 50m geofence circle
      _circles.add(
        Circle(
          circleId: CircleId(placeName),
          center: location,
          radius: _geofenceRadius,
          strokeWidth: 2,
          strokeColor: Colors.blue,
          fillColor: Colors.blue.withOpacity(0.1),
        ),
      );
    }
  }

  void _updateMapMarkers() {
    if (_currentPosition == null) return;

    // Add user location marker
    final userMarker = Marker(
      markerId: const MarkerId('user_location'),
      position: LatLng(_currentPosition!.latitude, _currentPosition!.longitude),
      infoWindow: const InfoWindow(title: 'Your Location'),
      icon: BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueAzure),
    );

    setState(() {
      _markers
          .removeWhere((marker) => marker.markerId.value == 'user_location');
      _markers.add(userMarker);
    });
  }

  Future<void> _moveCameraToUser() async {
    if (_currentPosition != null && _mapController != null) {
      await _mapController!.animateCamera(
        CameraUpdate.newLatLngZoom(
          LatLng(_currentPosition!.latitude, _currentPosition!.longitude),
          16,
        ),
      );
    }
  }

  // Inline helper functions
  double _calculateDistance(
      double lat1, double lon1, double lat2, double lon2) {
    const double earthRadius = 6371000; // Earth's radius in meters

    final dLat = _degreesToRadians(lat2 - lat1);
    final dLon = _degreesToRadians(lon2 - lon1);

    final a = sin(dLat / 2) * sin(dLat / 2) +
        cos(_degreesToRadians(lat1)) *
            cos(_degreesToRadians(lat2)) *
            sin(dLon / 2) *
            sin(dLon / 2);

    final c = 2 * atan2(sqrt(a), sqrt(1 - a));

    return earthRadius * c;
  }

  double _degreesToRadians(double degrees) {
    return degrees * (pi / 180);
  }

  Future<String> _reverseGeocode(double latitude, double longitude) async {
    try {
      final placemarks = await placemarkFromCoordinates(latitude, longitude);
      if (placemarks.isNotEmpty) {
        final placemark = placemarks.first;
        final parts = <String>[];

        if (placemark.name?.isNotEmpty == true) parts.add(placemark.name!);
        if (placemark.street?.isNotEmpty == true) parts.add(placemark.street!);
        if (placemark.locality?.isNotEmpty == true) {
          parts.add(placemark.locality!);
        }
        if (placemark.administrativeArea?.isNotEmpty == true) {
          parts.add(placemark.administrativeArea!);
        }
        if (placemark.postalCode?.isNotEmpty == true) {
          parts.add(placemark.postalCode!);
        }
        if (placemark.country?.isNotEmpty == true) {
          parts.add(placemark.country!);
        }

        return parts.isNotEmpty ? parts.join(', ') : 'Unknown address';
      }
    } catch (e) {
      // Fall through to return 'Unknown address'
    }
    return 'Unknown address';
  }

  void _showSnackBar(String message, {bool isError = false}) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: isError ? Colors.red : Colors.green,
      ),
    );
  }

  LatLng _getInitialCameraPosition() {
    // Average of the three locations
    double totalLat = 0;
    double totalLng = 0;

    for (final location in _locations.values) {
      totalLat += location.latitude;
      totalLng += location.longitude;
    }

    return LatLng(
      totalLat / _locations.length,
      totalLng / _locations.length,
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Time Tracking'),
        actions: [
          IconButton(
            icon: const Icon(Icons.my_location),
            onPressed: _moveCameraToUser,
            tooltip: 'Re-center',
          ),
        ],
      ),
      body: Column(
        children: [
          // Status bar
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(16),
            color: _isClockedIn ? Colors.green.shade100 : Colors.grey.shade100,
            child: Column(
              children: [
                Text(
                  _isClockedIn
                      ? 'Clocked in at $_currentPlaceName • ${DateFormat('HH:mm:ss').format(DateTime.now())}'
                      : 'Not clocked in',
                  style: const TextStyle(
                      fontSize: 16, fontWeight: FontWeight.bold),
                ),
                if (widget.scheduleId != null) ...[
                  const SizedBox(height: 8),
                  Chip(
                    label: Text(
                        'Schedule: ${widget.scheduleId!.substring(0, 8)}...'),
                    backgroundColor: Colors.blue.shade100,
                  ),
                ],
              ],
            ),
          ),

          // Map
          Expanded(
            child: _currentPosition == null
                ? const Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        CircularProgressIndicator(),
                        SizedBox(height: 16),
                        Text('Getting location...'),
                      ],
                    ),
                  )
                : GoogleMap(
                    initialCameraPosition: CameraPosition(
                      target: _getInitialCameraPosition(),
                      zoom: 16,
                    ),
                    markers: _markers,
                    circles: _circles,
                    onMapCreated: (controller) {
                      _mapController = controller;
                    },
                    myLocationEnabled: true,
                    myLocationButtonEnabled: false, // We have our own button
                  ),
          ),

          // Clock out button
          Padding(
            padding: const EdgeInsets.all(16),
            child: SizedBox(
              width: double.infinity,
              height: 50,
              child: ElevatedButton.icon(
                onPressed: _isClockedIn ? _manualClockOut : null,
                icon: const Icon(Icons.logout),
                label: const Text('Clock Out'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.red,
                  foregroundColor: Colors.white,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
