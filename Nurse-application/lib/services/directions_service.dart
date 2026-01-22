import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:google_maps_flutter/google_maps_flutter.dart';

import 'package:nurse_tracking_app/config/api_config.dart';

class DirectionsService {
  static String get _baseUrl => ApiConfig.directionsUrl;

  Future<DirectionsResult?> getDirections({
    required LatLng origin,
    required LatLng destination,
  }) async {
    try {
      debugPrint('🗺️ Fetching directions from backend...');
      final response = await http
          .post(
            Uri.parse(_baseUrl),
            headers: {'Content-Type': 'application/json'},
            body: jsonEncode({
              'origin': {
                'lat': origin.latitude,
                'lng': origin.longitude,
              },
              'destination': {
                'lat': destination.latitude,
                'lng': destination.longitude,
              },
            }),
          )
          .timeout(const Duration(seconds: 10));

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        return DirectionsResult(
          polylineEncoded: data['polyline'],
          distance: data['distance'],
          duration: data['duration'],
        );
      } else {
        debugPrint(
            '⚠️ Directions API Error: ${response.statusCode} ${response.body}');
        return null;
      }
    } catch (e) {
      debugPrint('❌ Network Error (Directions): $e');
      return null;
    }
  }
}

class DirectionsResult {
  final String polylineEncoded;
  final String distance;
  final String duration;

  DirectionsResult({
    required this.polylineEncoded,
    required this.distance,
    required this.duration,
  });
}
