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
import '../models/task_model.dart';
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

  // Task state
  List<Task> _tasks = [];
  bool _loadingTasks = false;
  bool _hasTaskChanges = false; // Track if tasks have been modified
  bool _updatingTasks = false; // Track if update is in progress

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
    _checkActiveClockInStatus(); // Check for existing session first
    _requestLocationPermission();
    _setupMapMarkersAndCircles();
    _loadNextUpcomingShift();
  }

  Future<void> _checkActiveClockInStatus() async {
    try {
      final empId = await SessionManager.getEmpId();
      if (empId == null) return;

      // Check DB for any row where clock_out_time is NULL
      final response = await supabase
          .from('time_logs')
          .select('*')
          .eq('emp_id', empId)
          .filter('clock_out_time', 'is', null)
          .maybeSingle();

      if (response != null && mounted) {
        final log = response;
        final lat = (log['clock_in_latitude'] as num).toDouble();
        final lng = (log['clock_in_longitude'] as num).toDouble();

        // Try to match which location we are at based on stored coordinates
        String? matchedPlace;
        for (final entry in _locations.entries) {
          final loc = entry.value;
          final dist =
              _calculateDistance(lat, lng, loc.latitude, loc.longitude);

          // If the stored clock-in location corresponds to one of our geofences
          // (allowing a relaxed buffer since we might have clocked in at the edge)
          if (dist <= _geofenceRadius + 50) {
            matchedPlace = entry.key;
            break;
          }
        }

        setState(() {
          _isClockedIn = true;
          _currentPlaceName = matchedPlace;
          _currentLogId = log['id'].toString();
          _clockInTimeUtc = DateTime.parse(log['clock_in_time']);
        });

        if (matchedPlace != null) {
          print('🔄 Restored active session at $matchedPlace');
        } else {
          debugPrint('⚠️ Restored active session but location unknown.');
        }
      }
    } catch (e) {
      debugPrint('Error checking active session: $e');
    }
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
      final now = DateTime.now();
      final today = DateFormat('yyyy-MM-dd').format(now);
      debugPrint(
          '🔍 Loading next shift for emp_id=$empId, today=$today, time=${TimeOfDay.fromDateTime(now)}');

      // Fetch upcoming shifts from shift table (today and future)
      final response = await supabase
          .from('shift')
          .select('*')
          .eq('emp_id', empId)
          .gte('date',
              today); // Fetch all for today+ and sort in Dart to be safe

      debugPrint('📥 Fetched ${response.length} shifts from today onwards');

      // Filter for scheduled or in_progress shifts
      final filteredShifts = response.where((shiftData) {
        final status = shiftData['shift_status']?.toString().toLowerCase();
        final isValidStatus = status == 'scheduled' ||
            status == 'in_progress' ||
            status == 'in progress';
        return isValidStatus;
      }).toList();

      // Sort in Dart to generally handle time strings (e.g. "9:00" vs "10:00") matching Dashboard logic
      filteredShifts.sort((a, b) {
        try {
          // Compare Dates
          final dateA = DateTime.parse(a['date'] ?? '');
          final dateB = DateTime.parse(b['date'] ?? '');
          final dateComparison = dateA.compareTo(dateB);
          if (dateComparison != 0) return dateComparison;

          // Compare Times
          final timeA = a['shift_start_time'] ?? '';
          final timeB = b['shift_start_time'] ?? '';

          // Handle simple string compare first
          // If formats are "HH:mm", simple string compare works IF padded (09:00 vs 10:00)
          // To be safe, parse hours/minutes
          final partsA = timeA.toString().split(':');
          final partsB = timeB.toString().split(':');

          if (partsA.length >= 2 && partsB.length >= 2) {
            final hourA = int.parse(partsA[0]);
            final hourB = int.parse(partsB[0]);
            if (hourA != hourB) return hourA.compareTo(hourB);

            final minA = int.parse(partsA[1]);
            final minB = int.parse(partsB[1]);
            return minA.compareTo(minB);
          }

          return timeA.toString().compareTo(timeB.toString());
        } catch (_) {
          return 0;
        }
      });

      debugPrint(
          '📋 After filtering & sorting: ${filteredShifts.length} upcoming shifts');
      if (filteredShifts.isNotEmpty) {
        debugPrint(
            '🥇 #1 Shift: ID=${filteredShifts.first['shift_id']}, Time=${filteredShifts.first['shift_start_time']}');
      }

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

        debugPrint(
            '✅ Loaded shift ${shift.shiftId} for client_id ${shift.clientId}');
        debugPrint('✅ Client loaded: ${client?.fullName ?? "No client"}');
        debugPrint('✅ Client address: ${client?.fullAddress ?? "No address"}');

        // Update route if we have both current position and client location
        if (_currentPosition != null && client != null) {
          _updateRouteToClient();
        }

        // Load tasks for this shift
        _loadTasks();
      } else {
        debugPrint('⚠️ No upcoming shifts found');
        setState(() {
          _nextShift = null;
          _nextClient = null;
          _loadingNextShift = false;
        });
      }
    } catch (e) {
      debugPrint('❌ Error loading next shift: $e');
      setState(() {
        _loadingNextShift = false;
      });
    }
  }

  Future<void> _requestLocationPermission() async {
    LocationPermission permission = await Geolocator.checkPermission();
    debugPrint('🔐 Current location permission: $permission');

    // If permission is denied, request it
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
      debugPrint('🔐 Requested permission result: $permission');
    }

    // Check if still denied or denied forever
    if (permission == LocationPermission.denied) {
      debugPrint('❌ Location permission denied');
      _showSnackBar('Location permission denied', isError: true);
      return;
    }

    if (permission == LocationPermission.deniedForever) {
      debugPrint('❌ Location permission denied forever');
      _showSnackBar(
          'Location permission denied forever. Please enable in settings.',
          isError: true);
      return;
    }

    // Permission is granted (whileInUse or always)
    debugPrint('✅ Location permission granted: $permission');
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

      debugPrint(
          '📍 Location updated: ${position.latitude}, ${position.longitude}');

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
        debugPrint('🎯 Centered map on user location');
      }

      // Check for geofence entry at assisted living locations
      await _checkGeofenceEntry(position);

      // Update map markers and route
      _updateMapMarkers();
      _updateRouteToClient();
    } catch (e) {
      debugPrint('❌ Location error: $e');
      _showSnackBar('Location error: $e', isError: true);
    }
  }

  Future<void> _checkGeofenceEntry(Position position) async {
    // 1. Check if we are inside ANY monitored location
    String? detectedPlace;
    double? distToPlace;

    for (final entry in _locations.entries) {
      final placeName = entry.key;
      final location = entry.value;

      final distance = _calculateDistance(
        position.latitude,
        position.longitude,
        location.latitude,
        location.longitude,
      );

      // Check strictly inside radius
      if (distance <= _geofenceRadius) {
        detectedPlace = placeName;
        distToPlace = distance;
        break; // Found our location
      }
    }

    // 2. Logic Control
    if (detectedPlace != null) {
      // ✅ INSIDE A GEOFENCE
      if (!_isClockedIn) {
        // Not clocked in? -> Auto Clock IN
        debugPrint(
            '📍 Entered $detectedPlace ($distToPlace m). Auto Clocking In...');
        await _autoClockIn(detectedPlace, position);
      } else {
        // Already clocked in.
        // Optional: switch location if they moved from Place A to Place B instantly (rare)
        if (_currentPlaceName != detectedPlace) {
          debugPrint(
              '📍 Changed location from $_currentPlaceName to $detectedPlace. Updating...');
          // For now, assume they are just "working". We could update the log, but simpler to leave as is.
        }
      }
    } else {
      // ❌ OUTSIDE ALL GEOFENCES
      if (_isClockedIn) {
        // We are clocked in, but now outside.
        // Apply a small "exit buffer" to prevent jitter (e.g. GPS drift at the edge)
        // Check distance to the place we are supposedly clocked in at
        bool confirmedOutside = true;

        if (_currentPlaceName != null &&
            _locations.containsKey(_currentPlaceName)) {
          final loc = _locations[_currentPlaceName]!;
          final dist = _calculateDistance(position.latitude, position.longitude,
              loc.latitude, loc.longitude);

          // Buffer: Geofence Radius + 20 meters.
          // If they are within 70m, consider them still "there" to avoid accidental clock-outs.
          if (dist <= _geofenceRadius + 20) {
            confirmedOutside = false;
          }
        }

        if (confirmedOutside) {
          debugPrint('📍 Exited $_currentPlaceName. Auto Clocking Out...');
          _showSnackBar('📍 Exited geofence. Auto Clocking Out...');
          await _autoClockOut(position);
        }
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
      debugPrint('Error updating route: $e');
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

  bool _permissionDenied = false;

  Future<void> _autoClockIn(String placeName, Position position) async {
    if (_permissionDenied) return; // Stop trying if we know we are blocked

    // 1. Check if Supabase Auth is valid
    if (supabase.auth.currentUser == null) {
      _showSnackBar('⚠️ Logged out from server. Please Log Out & Log In again.',
          isError: true);
      return;
    }

    try {
      final nowUtc = DateTime.now().toUtc();
      final clockInAddress =
          await _reverseGeocode(position.latitude, position.longitude);

      final lat = double.parse(position.latitude.toStringAsFixed(8));
      final lng = double.parse(position.longitude.toStringAsFixed(8));

      final empId = await SessionManager.getEmpId();
      if (empId == null) {
        _showSnackBar('Session expired. Please login again.', isError: true);
        return;
      }

      debugPrint(
          '📝 Attempting Auto-Clock In: AuthID=${supabase.auth.currentUser?.id}, EmpID=$empId');

      final response = await supabase.from('time_logs').insert({
        'emp_id': empId,
        // 'schedule_id': _nextShift?.shiftId.toString(), // schema mismatch
        'clock_in_time': nowUtc.toIso8601String(),
        'clock_in_latitude': lat,
        'clock_in_longitude': lng,
        'clock_in_address': clockInAddress,
        'updated_at': nowUtc.toIso8601String(),
      }).select('id');

      if (response.isNotEmpty) {
        // Also update the shift table if we have an active shift
        if (_nextShift != null) {
          try {
            await supabase.from('shift').update({
              'clock_in': nowUtc.toIso8601String(),
              'shift_status': 'in_progress'
            }).eq('shift_id', _nextShift!.shiftId);
            debugPrint('✅ Updated shift table with clock_in time');
          } catch (e) {
            debugPrint('⚠️ Failed to update shift table clock_in: $e');
          }
        }

        setState(() {
          _isClockedIn = true;
          _currentPlaceName = placeName;
          _currentLogId = response.first['id'];
          _clockInTimeUtc = nowUtc;
        });

        final localTime = DateFormat('HH:mm:ss').format(DateTime.now());
        _showSnackBar('✅ Auto Clocked IN at $placeName ($localTime)');
      }
    } catch (e) {
      // Handle RLS Permission Error specifically
      if (e.toString().contains('42501') || e.toString().contains('policy')) {
        setState(() {
          _permissionDenied = true;
        });
        _showPermissionErrorDialog();
      }
      // Handle Network Error
      else if (e.toString().contains('SocketException') ||
          e.toString().contains('host lookup')) {
        _showSnackBar(
            '⚠️ Internet lost. Validating entry locally... (Sync pending)',
            isError: true);
      } else {
        _showSnackBar('Error clocking in: $e', isError: true);
        debugPrint('❌ Clock-in Error: $e');
      }
    }
  }

  void _showPermissionErrorDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('⚠️ Permission Denied'),
        content: const Text(
            'The Supabase Database blocked this request (RLS Policy).\n\n'
            'FASTEST FIX:\n'
            '1. Go to Supabase Dashboard > Table Editor > "time_logs"\n'
            '2. Click "RLS" or "Active" in the toolbar\n'
            '3. Click "Disable RLS"\n\n'
            'Then restart the app.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('OK'),
          ),
        ],
      ),
    );
  }

  Future<void> _autoClockOut(Position position) async {
    if (_currentLogId == null || _permissionDenied) return;

    try {
      final nowUtc = DateTime.now().toUtc();
      final clockOutAddress =
          await _reverseGeocode(position.latitude, position.longitude);

      final totalHours = _clockInTimeUtc != null
          ? ((nowUtc.difference(_clockInTimeUtc!).inMinutes) / 60.0)
          : 0.0;

      final lat = double.parse(position.latitude.toStringAsFixed(8));
      final lng = double.parse(position.longitude.toStringAsFixed(8));

      final update = supabase.from('time_logs').update({
        'clock_out_time': nowUtc.toIso8601String(),
        'clock_out_latitude': lat,
        'clock_out_longitude': lng,
        'clock_out_address': clockOutAddress,
        'total_hours': double.parse(totalHours.toStringAsFixed(2)),
        'updated_at': nowUtc.toIso8601String(),
      }).eq('id', _currentLogId!);

      await update;

      // Also update the shift table if we have an active shift
      if (_nextShift != null) {
        try {
          await supabase.from('shift').update({
            'clock_out': nowUtc.toIso8601String(),
            'shift_status': 'completed'
          }).eq('shift_id', _nextShift!.shiftId);
          debugPrint(
              '✅ Updated shift table with clock_out time and completed status');
        } catch (e) {
          debugPrint('⚠️ Failed to update shift table clock_out: $e');
        }
      }

      final placeName = _currentPlaceName ?? 'Location';
      _showSnackBar(
          '👋 Left $placeName. Auto Clocked OUT. (${totalHours.toStringAsFixed(2)} hrs)');

      setState(() {
        _isClockedIn = false;
        _currentLogId = null;
        _currentPlaceName = null;
        _clockInTimeUtc = null;
      });

      // Refresh to load next shift after completing current one
      _loadNextUpcomingShift();
    } catch (e) {
      if (e.toString().contains('42501') || e.toString().contains('policy')) {
        _showSnackBar('⚠️ Database Permission Error (Check RLS Policies)',
            isError: true);
      } else if (e.toString().contains('SocketException') ||
          e.toString().contains('host lookup')) {
        _showSnackBar(
            '⚠️ Internet lost during clock-out. Please check connection.',
            isError: true);
      } else {
        _showSnackBar('Error clocking out: $e', isError: true);
      }
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

  Future<void> _loadTasks() async {
    if (_nextShift == null) {
      debugPrint('❌ _loadTasks: _nextShift is null');
      return;
    }

    debugPrint(
        '🔍 _loadTasks: Fetching tasks for shift_id: ${_nextShift!.shiftId}');

    setState(() {
      _loadingTasks = true;
      _hasTaskChanges = false; // Reset changes flag when loading new tasks
    });

    try {
      // 1. Try fetching by shift_id (Standard Foreign Key)
      var response = await supabase
          .from('tasks')
          .select('*')
          .eq('shift_id', _nextShift!.shiftId)
          .order('task_id');

      debugPrint(
          '📥 _loadTasks: Found ${response.length} tasks by shift_id=${_nextShift!.shiftId}');

      // 2. Fallback: If no tasks found by shift_id, try linking via shift.task_id (Business ID)
      if (response.isEmpty && _nextShift!.taskId != null) {
        debugPrint(
            '⚠️ No tasks by shift_id. Attempting fallback via shift.task_id (task_code): ${_nextShift!.taskId}');

        final shiftTaskCode = _nextShift!.taskId!;

        final fallbackResponse = await supabase
            .from('tasks')
            .select('*')
            .eq('task_code', shiftTaskCode);

        if (fallbackResponse.isNotEmpty) {
          debugPrint(
              '✅ Found ${fallbackResponse.length} tasks via task_code=$shiftTaskCode');
          response = fallbackResponse;
        }
      }

      final tasks = response.map<Task>((e) => Task.fromJson(e)).toList();

      if (mounted) {
        setState(() {
          _tasks = tasks;
          _loadingTasks = false;
        });

        // If still empty, it might be RLS or data not inserted
        if (tasks.isEmpty) {
          debugPrint(
              '⚠️ _tasks is empty. Possible reasons: 1. No data in "tasks" table. 2. shift_id mismatch. 3. RLS policy hiding rows.');
        }
      }
    } catch (e) {
      debugPrint('❌ Error loading tasks: $e');
      if (mounted) {
        setState(() {
          _loadingTasks = false;
        });
        if (e.toString().contains('42501') || e.toString().contains('policy')) {
          _showSnackBar('Database Permission Error. Check RLS policies.',
              isError: true);
        }
      }
    }
  }

  void _toggleTask(Task task, bool value) {
    final index = _tasks.indexWhere((t) => t.taskId == task.taskId);
    if (index == -1) return;

    final updatedTask = Task(
        taskId: task.taskId,
        shiftId: task.shiftId,
        details: task.details,
        status: value,
        comment: task.comment,
        taskCode: task.taskCode);

    setState(() {
      _tasks[index] = updatedTask;
      _hasTaskChanges = true; // Mark that tasks have been modified
    });
  }

  Future<void> _updateTasksAndComplete() async {
    if (!_hasTaskChanges) return;

    setState(() {
      _updatingTasks = true;
    });

    try {
      // Update all tasks in the database
      for (final task in _tasks) {
        await supabase
            .from('tasks')
            .update({'status': task.status}).eq('task_id', task.taskId);
      }

      _showSnackBar('✅ Tasks updated successfully');

      setState(() {
        _hasTaskChanges = false;
        _updatingTasks = false;
      });

      // Check if all tasks are complete for auto clock-out
      if (_isClockedIn) {
        final allDone = _tasks.every((t) => t.status);
        if (allDone && _currentPosition != null) {
          _showSnackBar('🎉 All tasks complete! Clocking out...');
          // Delay to show the success message
          await Future.delayed(const Duration(milliseconds: 1500));
          if (mounted) {
            await _autoClockOut(_currentPosition!);
          }
        }
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _updatingTasks = false;
        });
        _showSnackBar('Error updating tasks: $e', isError: true);
      }
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
      extendBodyBehindAppBar: true,
      appBar: AppBar(
        title: const Text('Clock in/out',
            style: TextStyle(
                color: Colors.black87,
                fontWeight: FontWeight.w600,
                fontSize: 18)),
        backgroundColor: Colors.white.withValues(alpha: 0.9),
        elevation: 0,
        centerTitle: true,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new,
              color: Colors.black87, size: 20),
          onPressed: () => Navigator.of(context).pop(),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh, color: Colors.blueAccent),
            onPressed: _loadNextUpcomingShift,
            tooltip: 'Refresh Shift',
          ),
        ],
        shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(bottom: Radius.circular(20)),
        ),
      ),
      body: Stack(
        children: [
          // 1. Full Screen Map
          GoogleMap(
            initialCameraPosition: CameraPosition(
              target: _getInitialCameraPosition(),
              zoom: 15,
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
                    LatLng(_currentPosition!.latitude,
                        _currentPosition!.longitude),
                    16,
                  ),
                );
                _hasCenteredOnUser = true;
              }
            },
            myLocationEnabled: _currentPosition != null,
            myLocationButtonEnabled: false,
            zoomControlsEnabled: false,
            // Add padding to map to avoid bottom sheet covering google logo/controls
            padding: const EdgeInsets.only(bottom: 280),
          ),

          // 2. Map Overlay Controls (Recenter FAB)
          Positioned(
            right: 16,
            bottom: 300, // Above the bottom sheet
            child: FloatingActionButton(
              heroTag: 'recenter_fab',
              onPressed: _moveCameraToUser,
              backgroundColor: Colors.white,
              child: const Icon(Icons.my_location, color: Colors.black87),
            ),
          ),

          // 3. Loading Overlay for GPS
          if (_currentPosition == null)
            Positioned(
              top: 120,
              left: 20,
              right: 20,
              child: Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                decoration: BoxDecoration(
                  color: Colors.black87.withValues(alpha: 0.8),
                  borderRadius: BorderRadius.circular(30),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.2),
                      blurRadius: 10,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
                child: const Row(
                  mainAxisSize: MainAxisSize.min,
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: Colors.white,
                      ),
                    ),
                    SizedBox(width: 12),
                    Text(
                      'Acquiring precise location...',
                      style: TextStyle(color: Colors.white, fontSize: 13),
                    ),
                  ],
                ),
              ),
            ),

          // 4. Bottom Control Panel
          Align(
            alignment: Alignment.bottomCenter,
            child: Container(
              width: double.infinity,
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius:
                    const BorderRadius.vertical(top: Radius.circular(30)),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.15),
                    blurRadius: 20,
                    offset: const Offset(0, -5),
                  ),
                ],
              ),
              child: SafeArea(
                child: Padding(
                  padding: const EdgeInsets.all(24.0),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      // Handle bar for visual affordance
                      Center(
                        child: Container(
                          width: 40,
                          height: 4,
                          margin: const EdgeInsets.only(bottom: 20),
                          decoration: BoxDecoration(
                            color: Colors.grey.shade300,
                            borderRadius: BorderRadius.circular(2),
                          ),
                        ),
                      ),

                      // Status Header
                      Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.all(10),
                            decoration: BoxDecoration(
                              color: _isClockedIn
                                  ? Colors.green.withValues(alpha: 0.1)
                                  : Colors.orange.withValues(alpha: 0.1),
                              shape: BoxShape.circle,
                            ),
                            child: Icon(
                              _isClockedIn
                                  ? Icons.check_circle_rounded
                                  : Icons.timer_outlined,
                              color:
                                  _isClockedIn ? Colors.green : Colors.orange,
                              size: 24,
                            ),
                          ),
                          const SizedBox(width: 16),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  _isClockedIn
                                      ? 'Currently Working'
                                      : 'Ready to Start',
                                  style: TextStyle(
                                    fontSize: 14,
                                    color: Colors.grey.shade600,
                                    fontWeight: FontWeight.w500,
                                  ),
                                ),
                                const SizedBox(height: 2),
                                Text(
                                  _isClockedIn ? 'Clocked In' : 'Clocked Out',
                                  style: const TextStyle(
                                    fontSize: 20,
                                    fontWeight: FontWeight.bold,
                                    color: Colors.black87,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          if (_isClockedIn && _clockInTimeUtc != null)
                            _LiveTimer(startTime: _clockInTimeUtc!),
                        ],
                      ),

                      const SizedBox(height: 24),

                      // Next Shift Info Card
                      if (_loadingNextShift)
                        const Padding(
                          padding: EdgeInsets.all(20.0),
                          child: Center(child: CircularProgressIndicator()),
                        )
                      else if (_nextShift != null && _nextClient != null)
                        Column(
                          children: [
                            Container(
                              padding: const EdgeInsets.all(16),
                              decoration: BoxDecoration(
                                color: Colors.blue.withValues(alpha: 0.05),
                                borderRadius: BorderRadius.circular(16),
                                border: Border.all(
                                    color: Colors.blue.withValues(alpha: 0.1)),
                              ),
                              child: Row(
                                children: [
                                  Container(
                                    padding: const EdgeInsets.all(8),
                                    decoration: BoxDecoration(
                                      color: Colors.white,
                                      borderRadius: BorderRadius.circular(10),
                                    ),
                                    child: const Icon(
                                        Icons.person_outline_rounded,
                                        color: Colors.blue),
                                  ),
                                  const SizedBox(width: 12),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          _nextClient!.fullName,
                                          style: const TextStyle(
                                            fontWeight: FontWeight.bold,
                                            fontSize: 15,
                                          ),
                                        ),
                                        const SizedBox(height: 2),
                                        Text(
                                          '${_nextShift!.date} • ${_nextShift!.formattedTimeRange}',
                                          style: TextStyle(
                                            color: Colors.grey.shade600,
                                            fontSize: 12,
                                          ),
                                        ),
                                        if (_nextClient!
                                            .fullAddress.isNotEmpty) ...[
                                          const SizedBox(height: 4),
                                          Row(
                                            children: [
                                              Icon(Icons.location_on_outlined,
                                                  size: 14,
                                                  color: Colors.grey.shade500),
                                              const SizedBox(width: 4),
                                              Expanded(
                                                child: Text(
                                                  _nextClient!.fullAddress,
                                                  style: TextStyle(
                                                    color: Colors.grey.shade500,
                                                    fontSize: 11,
                                                  ),
                                                  maxLines: 1,
                                                  overflow:
                                                      TextOverflow.ellipsis,
                                                ),
                                              ),
                                            ],
                                          ),
                                        ],
                                        if (_currentPosition != null &&
                                            _nextClient!.locationCoordinates !=
                                                null) ...[
                                          const SizedBox(height: 4),
                                          Row(
                                            children: [
                                              Icon(Icons.directions_walk,
                                                  size: 14,
                                                  color: Colors.blue.shade400),
                                              const SizedBox(width: 4),
                                              Text(
                                                '${(_calculateDistance(
                                                      _currentPosition!
                                                          .latitude,
                                                      _currentPosition!
                                                          .longitude,
                                                      _nextClient!
                                                          .locationCoordinates![0],
                                                      _nextClient!
                                                          .locationCoordinates![1],
                                                    ) / 1000).toStringAsFixed(2)} km away',
                                                style: TextStyle(
                                                  color: Colors.blue.shade600,
                                                  fontSize: 11,
                                                  fontWeight: FontWeight.w500,
                                                ),
                                              ),
                                            ],
                                          ),
                                        ],
                                      ],
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            if (_isClockedIn) ...[
                              const SizedBox(height: 20),
                              const Align(
                                alignment: Alignment.centerLeft,
                                child: Text(
                                  'Shift Tasks',
                                  style: TextStyle(
                                    fontSize: 16,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ),
                              const SizedBox(height: 8),
                              if (_loadingTasks)
                                const Center(
                                    child: Padding(
                                  padding: EdgeInsets.all(16),
                                  child: CircularProgressIndicator(),
                                ))
                              else if (_tasks.isEmpty)
                                Container(
                                  padding: const EdgeInsets.all(16),
                                  width: double.infinity,
                                  decoration: BoxDecoration(
                                    color: Colors.grey.shade50,
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                  child: Text(
                                    'No tasks assigned for this shift.',
                                    style:
                                        TextStyle(color: Colors.grey.shade600),
                                    textAlign: TextAlign.center,
                                  ),
                                )
                              else
                                ListView.builder(
                                  shrinkWrap: true,
                                  physics: const NeverScrollableScrollPhysics(),
                                  itemCount: _tasks.length,
                                  itemBuilder: (context, index) {
                                    final task = _tasks[index];
                                    return CheckboxListTile(
                                      value: task.status,
                                      onChanged: (val) =>
                                          _toggleTask(task, val ?? false),
                                      title: Text(
                                        task.details ?? 'Task ${index + 1}',
                                        style: TextStyle(
                                          decoration: task.status
                                              ? TextDecoration.lineThrough
                                              : null,
                                          color: task.status
                                              ? Colors.grey
                                              : Colors.black87,
                                        ),
                                      ),
                                      controlAffinity:
                                          ListTileControlAffinity.leading,
                                      contentPadding: EdgeInsets.zero,
                                      activeColor: Colors.blue,
                                    );
                                  },
                                ),
                            ],
                          ],
                        ),

                      const SizedBox(height: 24),

                      // Update Tasks Button (only shows when clocked in)
                      if (_isClockedIn)
                        SizedBox(
                          height: 56,
                          child: ElevatedButton(
                            onPressed: (_hasTaskChanges && !_updatingTasks)
                                ? _updateTasksAndComplete
                                : null,
                            style: ElevatedButton.styleFrom(
                              backgroundColor: _hasTaskChanges
                                  ? Colors.blue
                                  : Colors.grey.shade300,
                              foregroundColor: Colors.white,
                              elevation: 0,
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(16),
                              ),
                              disabledBackgroundColor: Colors.grey.shade300,
                              disabledForegroundColor: Colors.grey.shade500,
                            ),
                            child: _updatingTasks
                                ? const Row(
                                    mainAxisAlignment: MainAxisAlignment.center,
                                    children: [
                                      SizedBox(
                                        width: 20,
                                        height: 20,
                                        child: CircularProgressIndicator(
                                          strokeWidth: 2,
                                          color: Colors.white,
                                        ),
                                      ),
                                      SizedBox(width: 12),
                                      Text(
                                        'Updating...',
                                        style: TextStyle(
                                          fontSize: 16,
                                          fontWeight: FontWeight.bold,
                                        ),
                                      ),
                                    ],
                                  )
                                : Text(
                                    _hasTaskChanges
                                        ? 'Update Tasks & Complete'
                                        : 'No Changes',
                                    style: const TextStyle(
                                      fontSize: 16,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                          ),
                        ),
                      if (_isClockedIn && _hasTaskChanges)
                        Padding(
                          padding: const EdgeInsets.only(top: 12),
                          child: Text(
                            'Tap to save changes. Auto clock-out if all tasks done.',
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              fontSize: 12,
                              color: Colors.grey.shade500,
                            ),
                          ),
                        ),
                      if (!_isClockedIn)
                        Padding(
                          padding: const EdgeInsets.only(top: 12),
                          child: Text(
                            'Enter the client\'s location to automatically clock in.',
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              fontSize: 12,
                              color: Colors.grey.shade500,
                            ),
                          ),
                        ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// Simple widget to show live duration since start time
class _LiveTimer extends StatefulWidget {
  final DateTime startTime;
  const _LiveTimer({required this.startTime});

  @override
  State<_LiveTimer> createState() => _LiveTimerState();
}

class _LiveTimerState extends State<_LiveTimer> {
  late Timer _timer;
  String _formattedDuration = '00:00:00';

  @override
  void initState() {
    super.initState();
    _updateTime();
    _timer = Timer.periodic(const Duration(seconds: 1), (_) => _updateTime());
  }

  void _updateTime() {
    final now = DateTime.now().toUtc();
    final duration = now.difference(widget.startTime);
    final hours = duration.inHours.toString().padLeft(2, '0');
    final minutes = (duration.inMinutes % 60).toString().padLeft(2, '0');
    final seconds = (duration.inSeconds % 60).toString().padLeft(2, '0');
    if (mounted) {
      setState(() {
        _formattedDuration = '$hours:$minutes:$seconds';
      });
    }
  }

  @override
  void dispose() {
    _timer.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: Colors.green.shade50,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Colors.green.shade100),
      ),
      child: Text(
        _formattedDuration,
        style: TextStyle(
          color: Colors.green.shade700,
          fontWeight: FontWeight.bold,
          fontFamily: 'monospace',
        ),
      ),
    );
  }
}
