import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:supabase_flutter/supabase_flutter.dart';
import '../data/faq_data.dart';

/// Intents supported by the chatbot
enum IntentType {
  faq,
  callInSick,
  emergencyLeave, // NEW
  partialShiftChange,
  lateForShift,
  clientBookingEndedEarly,
  clientNotHome,
  clientCancelled,
}

/// Convert enum → backend format (snake_case)
String intentToCode(IntentType t) {
  switch (t) {
    case IntentType.callInSick:
      return "call_in_sick";

    case IntentType.emergencyLeave:
      return "emergency_leave"; // NEW

    case IntentType.partialShiftChange:
      return "partial_shift_change";

    case IntentType.lateForShift:
      return "late_notification";

    case IntentType.clientBookingEndedEarly:
      return "client_booking_ended_early";

    case IntentType.clientNotHome:
      return "client_not_home";

    case IntentType.clientCancelled:
      return "client_cancelled";

    default:
      return "faq";
  }
}

/// Parsed intent container
class ParsedIntent {
  final IntentType type;
  final String? startTime;
  final String? endTime;

  ParsedIntent({
    required this.type,
    this.startTime,
    this.endTime,
  });
}

/// Supabase edge function response model
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

  static final _client = Supabase.instance.client;

  static const _anonKey = 'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9...';

  // ---------------------------------------------------------------------------
  // 1) FRONTEND-SIDE INTENT DETECTION
  // ---------------------------------------------------------------------------
  static ParsedIntent detectIntent(String msg) {
    final lower = msg.toLowerCase();

    // Emergency Leave
    if (lower.contains("emergency leave") ||
        lower.contains("urgent leave") ||
        lower.contains("family emergency") ||
        lower.contains("emergency")) {
      return ParsedIntent(type: IntentType.emergencyLeave);
    }

    // Sick Leave
    if (lower.contains("call in sick") || lower.contains("sick")) {
      return ParsedIntent(type: IntentType.callInSick);
    }

    // Client booking ended early
    if (lower.contains("booking ended early") ||
        lower.contains("client booking ended early")) {
      return ParsedIntent(type: IntentType.clientBookingEndedEarly);
    }

    // Client not home
    if (lower.contains("client not home") ||
        lower.contains("client was not home")) {
      return ParsedIntent(type: IntentType.clientNotHome);
    }

    // Client cancelled
    if (lower.contains("client cancelled") ||
        lower.contains("client canceled")) {
      return ParsedIntent(type: IntentType.clientCancelled);
    }

    // Late
    if (lower.contains("late") ||
        lower.contains("running late") ||
        lower.contains("delay")) {
      return ParsedIntent(type: IntentType.lateForShift);
    }

    return ParsedIntent(type: IntentType.faq);
  }

  // ---------------------------------------------------------------------------
  // 2) MAIN PROCESSOR
  // ---------------------------------------------------------------------------
  static Future<String> processMessage(String message, int? empId) async {
    if (empId == null) return "Please log in first.";

    final parsed = detectIntent(message);
    final intentCode = intentToCode(parsed.type);

    // FAQ response — do not call backend
    if (parsed.type == IntentType.faq) {
      final faq = FAQData.findAnswer(message);
      return faq?['answer'] ??
          "I'm here to help with sick leave, emergency leave, client issues, schedule issues, lateness, and more.";
    }

    // Notify backend
    final response = await _sendToSupabase(
      empId: empId,
      message: message,
      intentType: intentCode,
      startTime: parsed.startTime,
      endTime: parsed.endTime,
    );

    if (!response.ok) {
      return "⚠️ Request logged but email not sent.";
    }

    return "✅ Request sent to ${response.supervisor ?? "your supervisor"}.";
  }

  // ---------------------------------------------------------------------------
  // 3) SEND TO SUPABASE EDGE FUNCTION
  // ---------------------------------------------------------------------------
  static Future<ChatbotResponse> _sendToSupabase({
    required int empId,
    required String message,
    required String intentType,
    String? startTime,
    String? endTime,
  }) async {
    try {
      final token = _client.auth.currentSession?.accessToken ?? _anonKey;
      const url = "$supabaseUrl/functions/v1/$edgeFunctionName";

      final body = {
        "emp_id": empId,
        "message": message,
        "intent_type": intentType,
        if (startTime != null) "start_time": startTime,
        if (endTime != null) "end_time": endTime,
      };

      final res = await http.post(
        Uri.parse(url),
        headers: {
          "Content-Type": "application/json",
          "Authorization": "Bearer $token",
        },
        body: jsonEncode(body),
      );

      if (res.statusCode == 200) {
        return ChatbotResponse.fromJson(jsonDecode(res.body));
      }

      return ChatbotResponse(ok: false, error: res.body);
    } catch (e) {
      return ChatbotResponse(ok: false, error: e.toString());
    }
  }

  // ---------------------------------------------------------------------------
  // 4) SIGNATURE VERSION
  // ---------------------------------------------------------------------------
  static Future<String> processMessageWithSignature(
    String message,
    int? empId,
    String signatureUrl,
  ) async {
    if (empId == null) return "Please log in first.";

    final parsed = detectIntent(message);
    final intentCode = intentToCode(parsed.type);

    final response = await _sendToSupabase(
      empId: empId,
      message: message,
      intentType: intentCode,
    );

    if (response.ok) {
      return "✅ Request with signature sent to ${response.supervisor}.";
    }

    return "⚠️ Request logged but email not sent.";
  }
}
