import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:supabase_flutter/supabase_flutter.dart';
import '../data/faq_data.dart';

enum IntentType { faq, fullDayLeave, partialShiftChange, lateForShift }

class ParsedIntent {
  final IntentType type;
  final String? startTime;
  final String? endTime;
  final String? reason;

  ParsedIntent({
    required this.type,
    this.startTime,
    this.endTime,
    this.reason,
  });

  factory ParsedIntent.faq() => ParsedIntent(type: IntentType.faq);

  factory ParsedIntent.fullDayLeave({String? reason}) =>
      ParsedIntent(type: IntentType.fullDayLeave, reason: reason);

  factory ParsedIntent.partialShiftChange({
    String? start,
    String? end,
    String? reason,
  }) =>
      ParsedIntent(
        type: IntentType.partialShiftChange,
        startTime: start,
        endTime: end,
        reason: reason,
      );

  factory ParsedIntent.lateForShift({String? reason}) =>
      ParsedIntent(type: IntentType.lateForShift, reason: reason);
}

class ChatbotResponse {
  final bool ok;
  final String? requestId;
  final bool? emailSent;
  final String? supervisor;
  final String? type;
  final String? error;

  ChatbotResponse({
    required this.ok,
    this.requestId,
    this.emailSent,
    this.supervisor,
    this.type,
    this.error,
  });

  factory ChatbotResponse.fromJson(Map<String, dynamic> json) =>
      ChatbotResponse(
        ok: json['ok'] ?? false,
        requestId: json['request_id'],
        emailSent: json['email_sent'],
        supervisor: json['supervisor'],
        type: json['type'],
        error: json['error'],
      );
}

class ChatbotService {
  static const String supabaseUrl = 'https://asbfhxdomvclwsrekdxi.supabase.co';
  static const String edgeFunctionName = 'chatbot-handle-request';

  // Use Supabase Flutter client instead of importing main.dart
  static final _client = Supabase.instance.client;

  // Anonymous key fallback (used if user isn’t logged in)
  static const _anonKey =
      'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6ImFzYmZoeGRvbXZjbHdzcmVrZHhpIiwicm9sZSI6ImFub24iLCJpYXQiOjE3NTQzMjI3OTUsImV4cCI6MjA2OTg5ODc5NX0.0VzbWIc-uxIDhI03g04n8HSPRQ_p01UTJQ1sg8ggigU';

  /// 🔍 Parse user message → detect intent
  static ParsedIntent parseMessage(String msg) {
    final lower = msg.toLowerCase();

    // Full-day leave intent
    if (['leave', 'off', 'day off', 'take off', 'not coming']
        .any((k) => lower.contains(k))) {
      return ParsedIntent.fullDayLeave(reason: msg);
    }

    // Late-for-shift intent
    if (['late', 'running late', 'be late'].any((k) => lower.contains(k))) {
      return ParsedIntent.lateForShift(reason: msg);
    }

    // Shift time change intent: “from 9am to 11am” or “9 to 11”
    final timePattern = RegExp(
      r'from\s+(\d{1,2})\s*(am|pm)?\s*to\s+(\d{1,2})\s*(am|pm)?',
      caseSensitive: false,
    );
    final match = timePattern.firstMatch(lower);
    if (match != null) {
      return ParsedIntent.partialShiftChange(
        start: match.group(1),
        end: match.group(3),
        reason: msg,
      );
    }

    // Simple pattern fallback
    final simplePattern = RegExp(
        r'(\d{1,2})\s*(am|pm)?\s*to\s+(\d{1,2})\s*(am|pm)?',
        caseSensitive: false);
    final simpleMatch = simplePattern.firstMatch(lower);
    if (simpleMatch != null &&
        (lower.contains('cannot') || lower.contains('can\'t'))) {
      return ParsedIntent.partialShiftChange(
        start: simpleMatch.group(1),
        end: simpleMatch.group(3),
        reason: msg,
      );
    }

    // Default → FAQ query
    return ParsedIntent.faq();
  }

  /// 💬 Main message handler
  static Future<String> processMessage(String message, int? empId) async {
    final intent = parseMessage(message);

    switch (intent.type) {
      case IntentType.faq:
        final faq = FAQData.findAnswer(message);
        if (faq != null) return faq['answer']!;
        return "I'm here to help! You can ask me about:\n• Clock in/out\n• Injury reports\n• Leave requests\n• Shift changes\n• Lateness notifications";

      case IntentType.fullDayLeave:
        if (empId == null) return 'Please log in to request leave.';
        return _handleLeaveRequest(message, empId);

      case IntentType.partialShiftChange:
        if (empId == null) return 'Please log in to request shift changes.';
        return _handleShiftChangeRequest(message, empId);

      case IntentType.lateForShift:
        if (empId == null) return 'Please log in to notify about lateness.';
        return _handleLateNotification(message, empId);
    }
  }

  /// 🏖️ Handle full-day leave
  static Future<String> _handleLeaveRequest(String message, int empId) async {
    final response = await callEdgeFunction(empId: empId, message: message);
    if (response.ok) {
      return '✅ Leave request sent to ${response.supervisor ?? "your supervisor"}.\nThey’ve been notified by email.';
    }
    return '⚠️ Leave request logged (email not sent). Please confirm with your supervisor.';
  }

  /// ⏰ Handle partial shift change
  static Future<String> _handleShiftChangeRequest(
      String message, int empId) async {
    final response = await callEdgeFunction(empId: empId, message: message);
    if (response.ok) {
      return '✅ Shift change request sent to ${response.supervisor ?? "your supervisor"}.\nThey will review and confirm.';
    }
    return '⚠️ Shift change logged (email not sent). Your supervisor will still see it.';
  }

  /// 🚶 Handle late notification
  static Future<String> _handleLateNotification(
      String message, int empId) async {
    final response = await callEdgeFunction(empId: empId, message: message);
    if (response.ok) {
      return '✅ Supervisor ${response.supervisor ?? ""} notified about your delay.\nPlease update them once you arrive.';
    }
    return '⚠️ Delay logged (email not sent).';
  }

  /// 🌐 Call Supabase Edge Function
  static Future<ChatbotResponse> callEdgeFunction({
    required int empId,
    required String message,
  }) async {
    try {
      final token = _client.auth.currentSession?.accessToken ?? _anonKey;
      final url = '$supabaseUrl/functions/v1/$edgeFunctionName';

      final response = await http.post(
        Uri.parse(url),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $token',
        },
        body: jsonEncode({'emp_id': empId, 'message': message}),
      );

      if (response.statusCode == 200) {
        return ChatbotResponse.fromJson(jsonDecode(response.body));
      } else {
        print('Edge Function failed: ${response.statusCode} ${response.body}');
        return ChatbotResponse(ok: false, error: 'Request failed.');
      }
    } catch (e) {
      print('Error calling chatbot Edge Function: $e');
      return ChatbotResponse(ok: false, error: e.toString());
    }
  }
}
