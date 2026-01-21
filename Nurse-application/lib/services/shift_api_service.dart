import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import '../models/shift_offer.dart';

/// Service for handling shift offer API requests
class ShiftApiService {
  final String baseUrl;

  ShiftApiService({required this.baseUrl});

  /// Respond to a shift offer (accept or reject)
  Future<bool> respondToShiftOffer({
    required int empId,
    required int shiftId,
    required ShiftOfferResponse response,
  }) async {
    try {
      debugPrint('📤 Responding to shift $shiftId: ${response.name}');

      final url = Uri.parse('$baseUrl/shift_offer/respond');
      final responseData = await http.post(
        url,
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'emp_id': empId,
          'shift_id': shiftId,
          'response': response.name,
          'timestamp': DateTime.now().toIso8601String(),
        }),
      );

      if (responseData.statusCode == 200 || responseData.statusCode == 201) {
        debugPrint('✅ Shift response sent successfully');
        return true;
      } else {
        debugPrint('❌ Failed to send response: ${responseData.statusCode}');
        debugPrint('Response body: ${responseData.body}');
        return false;
      }
    } catch (e) {
      debugPrint('❌ Error responding to shift offer: $e');
      return false;
    }
  }

  /// Fetch pending shift offers (for offline recovery)
  Future<List<ShiftOffer>> fetchPendingOffers(int empId) async {
    try {
      debugPrint('📥 Fetching pending offers for employee $empId');

      final url = Uri.parse('$baseUrl/shift_offers/pending/$empId');
      final response = await http.get(url);

      if (response.statusCode == 200) {
        final List<dynamic> data = jsonDecode(response.body) as List;
        final offers = data
            .map((json) => ShiftOffer.fromJson(json as Map<String, dynamic>))
            .toList();

        debugPrint('✅ Fetched ${offers.length} pending offers');
        return offers;
      } else {
        debugPrint('❌ Failed to fetch pending offers: ${response.statusCode}');
        return [];
      }
    } catch (e) {
      debugPrint('❌ Error fetching pending offers: $e');
      return [];
    }
  }

  /// Get shift offer history for an employee
  Future<List<ShiftOffer>> fetchShiftOfferHistory({
    required int empId,
    int limit = 50,
  }) async {
    try {
      debugPrint('📥 Fetching shift offer history for employee $empId');

      final url =
          Uri.parse('$baseUrl/shift_offers/history/$empId?limit=$limit');
      final response = await http.get(url);

      if (response.statusCode == 200) {
        final List<dynamic> data = jsonDecode(response.body) as List;
        final offers = data
            .map((json) => ShiftOffer.fromJson(json as Map<String, dynamic>))
            .toList();

        debugPrint('✅ Fetched ${offers.length} historical offers');
        return offers;
      } else {
        debugPrint('❌ Failed to fetch history: ${response.statusCode}');
        return [];
      }
    } catch (e) {
      debugPrint('❌ Error fetching shift offer history: $e');
      return [];
    }
  }

  /// Check if a shift offer is still available
  Future<bool> isShiftAvailable(int shiftId) async {
    try {
      final url = Uri.parse('$baseUrl/shift_offer/$shiftId/available');
      final response = await http.get(url);

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body) as Map<String, dynamic>;
        return data['available'] == true;
      }
      return false;
    } catch (e) {
      debugPrint('❌ Error checking shift availability: $e');
      return false;
    }
  }
}

/// Response options for shift offers
enum ShiftOfferResponse {
  accepted,
  rejected,
}
