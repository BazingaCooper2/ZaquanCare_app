import 'dart:async';
import 'dart:convert';
import 'dart:math';
import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:geolocator/geolocator.dart';
import 'package:geocoding/geocoding.dart';
import 'package:intl/intl.dart';
import 'package:http/http.dart' as http;
import '../main.dart';
import '../models/employee.dart';
import '../models/shift.dart';
import '../models/client.dart';
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
  final Set<Polyline> _polylines = {};
  bool _hasCenteredOnUser = false;

  // Next shift and client state
  Shift? _nextShift;
  Client? _nextClient;
  bool _loadingNextShift = false;

  // Assisted-Living locations with 50m geofence
  static const Map<String, LatLng> _locations = {
    'Willow Place': LatLng(43.538165, -80.311467),
    '85 Neeve': LatLng(43.536884, -80.307129),
    '87 Neeve': LatLng(43.536732, -80.307545),
  };

  static const double _geofenceRadius = 50.0; // meters
  static const String _googleMapsApiKey =
      'AIzaSyAVQpP_nIRtt5-gNFMZyxzfFC9yzYKQgFE';

  @override
  void initState() {
    super.initState();
    _requestLocationPermission();
    _setupMapMarkersAndCircles();
    _loadNextUpcomingShift();
  }

  @override
  void dispose() {
    _locationTimer?.cancel();
    _positionSubscription?.cancel();
    _mapController?.dispose();
    super.dispose();
  }

  Future<void> _loadNextUpcomingShift() async {
    setState(() {
      _loadingNextShift = true;
    });

    try {
      final empId = await SessionManager.getEmpId();
      if (empId == null) {
        setState(() {
          _loadingNextShift = false;
        });
        return;
      }

      // Get today's date
      final today = DateFormat('yyyy-MM-dd').format(DateTime.now());

      // Fetch next upcoming shift from shift table
      final response = await supabase
          .from('shift')
          .select('*')
          .eq('emp_id', empId)
          .gte('date', today)
          .order('date')
          .order('shift_start_time');

      // Filter for scheduled or in_progress shifts
      final filteredShifts = response.where((shiftData) {
        final status = shiftData['shift_status']?.toString().toLowerCase();
        return status == 'scheduled' ||
            status == 'in_progress' ||
            status == 'in progress';
      }).toList();

      if (filteredShifts.isNotEmpty) {
        final shift = Shift.fromJson(filteredShifts.first);

        // Fetch client details if client_id exists
        Client? client;
        if (shift.clientId != null) {
          final clientResponse = await supabase
              .from('client')
              .select('*')
              .eq('client_id', shift.clientId!)
              .limit(1);

          if (clientResponse.isNotEmpty) {
            client = Client.fromJson(clientResponse.first);
          }
        }

        setState(() {
          _nextShift = shift;
          _nextClient = client;
          _loadingNextShift = false;
        });

        // Update route if we have both current position and client location
        if (_currentPosition != null && client != null) {
          _updateRouteToClient();
        }
      } else {
        setState(() {
          _loadingNextShift = false;
        });
      }
    } catch (e) {
      print('Error loading next shift: $e');
      setState(() {
        _loadingNextShift = false;
      });
    }
  }

  Future<void> _requestLocationPermission() async {
    LocationPermission permission = await Geolocator.checkPermission();
    print('🔐 Current location permission: $permission');

    // If permission is denied, request it
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
      print('🔐 Requested permission result: $permission');
    }

    // Check if still denied or denied forever
    if (permission == LocationPermission.denied) {
      print('❌ Location permission denied');
      _showSnackBar('Location permission denied', isError: true);
      return;
    }

    if (permission == LocationPermission.deniedForever) {
      print('❌ Location permission denied forever');
      _showSnackBar(
          'Location permission denied forever. Please enable in settings.',
          isError: true);
      return;
    }

    // Permission is granted (whileInUse or always)
    print('✅ Location permission granted: $permission');
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

      print('📍 Location updated: ${position.latitude}, ${position.longitude}');

      setState(() {
        _currentPosition = position;
      });

      // Update address if not already set
      _currentAddress ??=
          await _reverseGeocode(position.latitude, position.longitude);

      // Center camera on user location first time
      if (!_hasCenteredOnUser && _mapController != null) {
        await _mapController!.animateCamera(
          CameraUpdate.newLatLngZoom(
            LatLng(position.latitude, position.longitude),
            16,
          ),
        );
        _hasCenteredOnUser = true;
        print('🎯 Centered map on user location');
      }

      // Check for geofence entry at assisted living locations
      await _checkGeofenceEntry(position);

      // Update map markers and route
      _updateMapMarkers();
      _updateRouteToClient();
    } catch (e) {
      print('❌ Location error: $e');
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

  Future<void> _updateRouteToClient() async {
    if (_currentPosition == null || _nextClient == null) return;

    final coordinates = _nextClient!.locationCoordinates;
    if (coordinates == null || coordinates.length < 2) return;

    final destinationLat = coordinates[0];
    final destinationLng = coordinates[1];

    try {
      // Use Google Directions API to get route
      final origin =
          '${_currentPosition!.latitude},${_currentPosition!.longitude}';
      final destination = '$destinationLat,$destinationLng';

      final url = Uri.parse(
        'https://maps.googleapis.com/maps/api/directions/json?origin=$origin&destination=$destination&key=$_googleMapsApiKey',
      );

      final response = await http.get(url);
      final data = json.decode(response.body);

      if (data['status'] == 'OK' && data['routes'].isNotEmpty) {
        final route = data['routes'][0];
        final overviewPolyline = route['overview_polyline']['points'];

        // Decode polyline points
        final points = _decodePolyline(overviewPolyline);

        setState(() {
          _polylines.clear();
          _polylines.add(
            Polyline(
              polylineId: const PolylineId('route_to_client'),
              points: points,
              color: Colors.blue,
              width: 5,
              geodesic: true,
            ),
          );
        });

        // Update camera to show both locations
        if (_mapController != null && points.isNotEmpty) {
          await _mapController!.animateCamera(
            CameraUpdate.newLatLngBounds(
              _boundsFromLatLngList([
                LatLng(_currentPosition!.latitude, _currentPosition!.longitude),
                LatLng(destinationLat, destinationLng),
              ]),
              100.0,
            ),
          );
        }
      }
    } catch (e) {
      print('Error updating route: $e');
    }
  }

  List<LatLng> _decodePolyline(String encoded) {
    final List<LatLng> poly = [];
    int index = 0;
    final int len = encoded.length;
    int lat = 0;
    int lng = 0;

    while (index < len) {
      int b, shift = 0, result = 0;
      do {
        b = encoded.codeUnitAt(index++) - 63;
        result |= (b & 0x1f) << shift;
        shift += 5;
      } while (b >= 0x20);
      final dlat = ((result & 1) != 0) ? ~(result >> 1) : (result >> 1);
      lat += dlat;

      shift = 0;
      result = 0;
      do {
        b = encoded.codeUnitAt(index++) - 63;
        result |= (b & 0x1f) << shift;
        shift += 5;
      } while (b >= 0x20);
      final dlng = ((result & 1) != 0) ? ~(result >> 1) : (result >> 1);
      lng += dlng;

      poly.add(LatLng(lat / 1e5, lng / 1e5));
    }

    return poly;
  }

  LatLngBounds _boundsFromLatLngList(List<LatLng> list) {
    double? x0, x1, y0, y1;
    for (final LatLng latLng in list) {
      if (x0 == null) {
        x0 = x1 = latLng.latitude;
        y0 = y1 = latLng.longitude;
      } else {
        if (latLng.latitude > x1!) x1 = latLng.latitude;
        if (latLng.latitude < x0) x0 = latLng.latitude;
        if (latLng.longitude > y1!) y1 = latLng.longitude;
        if (latLng.longitude < y0!) y0 = latLng.longitude;
      }
    }
    return LatLngBounds(
      southwest: LatLng(x0 ?? 0, y0 ?? 0),
      northeast: LatLng(x1 ?? 0, y1 ?? 0),
    );
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
        'schedule_id': _nextShift?.shiftId.toString(),
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
        _showSnackBar('Unable to find the current log to update.',
            isError: true);
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

    // Add markers and circles for assisted living locations
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
          fillColor: Colors.blue.withValues(alpha: 0.1),
        ),
      );
    }

    // Add patient destination marker if we have next client
    if (_nextClient != null) {
      final coordinates = _nextClient!.locationCoordinates;
      if (coordinates != null && coordinates.length >= 2) {
        _markers.add(
          Marker(
            markerId: const MarkerId('patient_destination'),
            position: LatLng(coordinates[0], coordinates[1]),
            infoWindow: InfoWindow(
              title: _nextClient!.fullName,
              snippet: _nextClient!.fullAddress,
            ),
            icon: BitmapDescriptor.defaultMarkerWithHue(
                BitmapDescriptor.hueGreen),
          ),
        );
      }
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
    // If we have next client location, center there; otherwise average of locations
    if (_nextClient != null) {
      final coordinates = _nextClient!.locationCoordinates;
      if (coordinates != null && coordinates.length >= 2) {
        return LatLng(coordinates[0], coordinates[1]);
      }
    }

    // Average of the three assisted living locations
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
            icon: const Icon(Icons.refresh),
            onPressed: _loadNextUpcomingShift,
            tooltip: 'Refresh',
          ),
          IconButton(
            icon: const Icon(Icons.my_location),
            onPressed: _moveCameraToUser,
            tooltip: 'Re-center',
          ),
        ],
      ),
      body: Column(
        children: [
          // Status bar with next shift info
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(16),
            color: _isClockedIn ? Colors.green.shade100 : Colors.grey.shade100,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Icon(
                      _isClockedIn ? Icons.check_circle : Icons.schedule,
                      color: _isClockedIn ? Colors.green : Colors.grey,
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        _isClockedIn
                            ? 'Clocked in at $_currentPlaceName'
                            : 'Not clocked in',
                        style: const TextStyle(
                            fontSize: 16, fontWeight: FontWeight.bold),
                      ),
                    ),
                  ],
                ),
                if (_nextShift != null && _nextClient != null) ...[
                  const SizedBox(height: 12),
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Colors.blue.shade50,
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: Colors.blue.shade200),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            const Icon(Icons.location_on,
                                size: 16, color: Colors.blue),
                            const SizedBox(width: 4),
                            Expanded(
                              child: Text(
                                'Next Patient: ${_nextClient!.fullName}',
                                style: const TextStyle(
                                    fontWeight: FontWeight.bold,
                                    color: Colors.blue),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 4),
                        Text(
                          _nextClient!.fullAddress,
                          style: const TextStyle(fontSize: 12),
                        ),
                        if (_nextShift!.date != null &&
                            _nextShift!.shiftStartTime != null)
                          Text(
                            '${_nextShift!.date} • ${_nextShift!.shiftStartTime}',
                            style: const TextStyle(
                                fontSize: 12, color: Colors.grey),
                          ),
                      ],
                    ),
                  ),
                ] else if (_loadingNextShift) ...[
                  const SizedBox(height: 12),
                  const Row(
                    children: [
                      SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      ),
                      SizedBox(width: 8),
                      Text('Loading next shift...'),
                    ],
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
                    polylines: _polylines,
                    onMapCreated: (controller) async {
                      _mapController = controller;
                      
                      // Center on user location if already available
                      if (_currentPosition != null && !_hasCenteredOnUser) {
                        await controller.animateCamera(
                          CameraUpdate.newLatLngZoom(
                            LatLng(_currentPosition!.latitude, _currentPosition!.longitude),
                            16,
                          ),
                        );
                        _hasCenteredOnUser = true;
                      }
                    },
                    myLocationEnabled: true,
                    myLocationButtonEnabled: false, // We have our own button
                  ),
          ),

          // Clock in/out buttons
          Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                if (!_isClockedIn) ...[
                  Expanded(
                    child: ElevatedButton.icon(
                      onPressed: null, // Geofence auto clock-in
                      icon: const Icon(Icons.location_on),
                      label: const Text('Auto Clock-In (Geofence)'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.blue,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 12),
                      ),
                    ),
                  ),
                ] else ...[
                  Expanded(
                    child: ElevatedButton.icon(
                      onPressed: _manualClockOut,
                      icon: const Icon(Icons.logout),
                      label: const Text('Clock Out'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.red,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 12),
                      ),
                    ),
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}
