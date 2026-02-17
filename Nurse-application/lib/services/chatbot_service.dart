import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:mailer/mailer.dart';
import 'package:mailer/smtp_server/gmail.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../data/faq_data.dart';

/// Intents supported by the chatbot
enum IntentType {
  faq,
  callInSick,
  emergencyLeave, // NEW
  emergencyHelp,
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

    case IntentType.emergencyHelp:
      return "emergency_help";

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
  final String? supervisor;
  final String? supervisorEmail;
  final String? employeeName;
  final String? type;
  final String? error;

  ChatbotResponse({
    required this.ok,
    this.requestId,
    this.supervisor,
    this.supervisorEmail,
    this.employeeName,
    this.type,
    this.error,
  });

  factory ChatbotResponse.fromJson(Map<String, dynamic> json) =>
      ChatbotResponse(
        ok: json['ok'] ?? false,
        requestId: json['request_id'],
        supervisor: json['supervisor'],
        supervisorEmail: json['supervisor_email'],
        employeeName: json['employee_name'],
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

    // Emergency Help
    if (lower.contains("emergency") &&
        (lower.contains("help") ||
            lower.contains("911") ||
            lower.contains("sos"))) {
      return ParsedIntent(type: IntentType.emergencyHelp);
    }

    // Emergency Leave
    if (lower.contains("emergency") &&
        (lower.contains("leave") || lower.contains("urgent"))) {
      return ParsedIntent(type: IntentType.emergencyLeave);
    }

    // Sick Leave
    if (lower.contains("sick") ||
        lower.contains("call in sick") ||
        lower.contains("feeling unwell") ||
        lower.contains("not well")) {
      return ParsedIntent(type: IntentType.callInSick);
    }

    // Client booking ended early
    if ((lower.contains("booking") && lower.contains("ended")) ||
        (lower.contains("booking") && lower.contains("early")) ||
        (lower.contains("shift") &&
            lower.contains("ended") &&
            lower.contains("early")) ||
        (lower.contains("client") &&
            lower.contains("ended") &&
            lower.contains("early"))) {
      return ParsedIntent(type: IntentType.clientBookingEndedEarly);
    }

    // Client not home
    if ((lower.contains("client") &&
            lower.contains("not") &&
            lower.contains("home")) ||
        (lower.contains("client") && lower.contains("not home")) ||
        (lower.contains("client") && lower.contains("wasn't home")) ||
        (lower.contains("client") && lower.contains("absent")) ||
        (lower.contains("nobody") && lower.contains("home"))) {
      return ParsedIntent(type: IntentType.clientNotHome);
    }

    // Client cancelled
    if ((lower.contains("client") &&
            (lower.contains("cancelled") || lower.contains("canceled"))) ||
        (lower.contains("client") && lower.contains("cancel")) ||
        (lower.contains("shift") &&
            (lower.contains("cancelled") || lower.contains("canceled"))) ||
        (lower.contains("appointment") &&
            (lower.contains("cancelled") || lower.contains("canceled")))) {
      return ParsedIntent(type: IntentType.clientCancelled);
    }

    // Late
    if (lower.contains("late") ||
        lower.contains("running late") ||
        lower.contains("delay") ||
        lower.contains("delayed")) {
      return ParsedIntent(type: IntentType.lateForShift);
    }

    // Partial Shift Change
    if ((lower.contains("shift") && lower.contains("change")) ||
        (lower.contains("reschedule")) ||
        (lower.contains("modify") && lower.contains("shift"))) {
      return ParsedIntent(type: IntentType.partialShiftChange);
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
      if (faq != null && faq['answer'] != null) {
        return faq['answer'] as String;
      }
      // Fallback for irrelevant messages
      return "Please contact your supervisor for assistance.";
    }

    if (parsed.type == IntentType.emergencyHelp) {
      return "Call 911 or click the SOS button in the dashboard";
    }

    // These intents are handled by UI dialogs, not backend auto-send
    if (parsed.type == IntentType.callInSick ||
        parsed.type == IntentType.clientBookingEndedEarly ||
        parsed.type == IntentType.clientNotHome ||
        parsed.type == IntentType.clientCancelled) {
      // Dialog will be shown by _sendMessage in chatbot_modal.dart
      // This code path shouldn't be reached if the dialog is properly triggered
      return "Please use the dialog to confirm this action.";
    }

    // Only send to backend for: late, emergency leave, shift changes
    if (parsed.type == IntentType.lateForShift ||
        parsed.type == IntentType.emergencyLeave ||
        parsed.type == IntentType.partialShiftChange) {
      // Notify backend
      final response = await _sendToSupabase(
        empId: empId,
        message: message,
        intentType: intentCode,
        startTime: parsed.startTime,
        endTime: parsed.endTime,
      );

      if (!response.ok) {
        return "⚠️ Request failed. Please try again.";
      }

      // Send email to supervisor via Gmail SMTP
      if (response.supervisorEmail != null) {
        try {
          await _sendSupervisorEmail(
            toEmail: response.supervisorEmail!,
            subject: 'Nurse Shift / Leave Notification',
            employeeName: response.employeeName ?? 'Employee',
            intentType: intentCode,
            message: message,
          );
        } catch (e) {
          debugPrint('⚠️ Email send failed: $e');
        }
      }

      return "✅ Request sent to ${response.supervisor ?? "your supervisor"}.";
    }

    // Fallback for any unhandled intents
    return "Please contact your supervisor for assistance.";
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
    String? signatureUrl,
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
        if (signatureUrl != null) "signature_url": signatureUrl,
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
      signatureUrl: signatureUrl,
    );

    if (response.ok) {
      // Send email to supervisor via Gmail SMTP
      if (response.supervisorEmail != null) {
        try {
          await _sendSupervisorEmail(
            toEmail: response.supervisorEmail!,
            subject: 'Nurse Shift / Leave Notification',
            employeeName: response.employeeName ?? 'Employee',
            intentType: intentCode,
            message: message,
          );
        } catch (e) {
          debugPrint('⚠️ Email send failed: $e');
        }
      }
      return "✅ Request with signature sent to ${response.supervisor}.";
    }

    return "⚠️ Request failed. Please try again.";
  }

  // ---------------------------------------------------------------------------
  // 5) SEND EMAIL VIA GMAIL SMTP
  // ---------------------------------------------------------------------------
  static Future<void> _sendSupervisorEmail({
    required String toEmail,
    required String subject,
    required String employeeName,
    required String intentType,
    required String message,
  }) async {
    const senderEmail = 'sk7949644@gmail.com';
    const senderPassword = 'ziet bnzk eyuf txyu';

    final smtpServer = gmail(senderEmail, senderPassword);

    String body;
    switch (intentType) {
      case 'call_in_sick':
        body = '$employeeName is calling in sick.\n\nMessage: $message';
        break;
      case 'emergency_leave':
        body =
            '$employeeName has requested EMERGENCY LEAVE.\n\nMessage: $message';
        break;
      case 'late_notification':
        body =
            '$employeeName will be late for their shift.\n\nMessage: $message';
        break;
      case 'client_not_home':
        body = '$employeeName reports: Client not home.\n\nMessage: $message';
        break;
      case 'client_cancelled':
        body = '$employeeName reports: Client cancelled.\n\nMessage: $message';
        break;
      default:
        body = '$employeeName submitted a request.\n\nMessage: $message';
    }

    final emailMessage = Message()
      ..from = const Address(senderEmail, 'ZaqenCare App')
      ..recipients.add(toEmail)
      ..subject = subject
      ..text = body;

    await send(emailMessage, smtpServer);
    debugPrint('✅ Email sent to $toEmail');
  }
}
