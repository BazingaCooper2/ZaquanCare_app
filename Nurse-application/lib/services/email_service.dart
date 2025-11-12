import 'package:mailer/mailer.dart';
import 'package:mailer/smtp_server.dart';
import 'dart:typed_data';
import 'dart:async';

class EmailService {
  // Gmail SMTP configuration
  static const String _smtpServer = 'smtp.gmail.com';
  static const int _smtpPort = 587;
  static const String _managerEmail = 'sk7949644@gmail.com';

  // You'll need to set these as environment variables or in a config file
  static const String _senderEmail =
      'sk7949644@gmail.com'; // Replace with your app's email
  static const String _senderPassword =
      'ziet bnzk eyuf txyu'; // Replace with your app password

  /// Sends an injury report email to the manager
  static Future<bool> sendInjuryReport({
    required String date,
    required String injuredPerson,
    required String reportingEmployee,
    required String location,
    required String description,
    required String severity,
    required String status,
    Uint8List? signatureImage,
  }) async {
    try {
      // Create SMTP server configuration
      final smtpServer = SmtpServer(
        _smtpServer,
        port: _smtpPort,
        username: _senderEmail,
        password: _senderPassword,
        allowInsecure: false,
        ignoreBadCertificate: false,
      );

      // Create email message
      final message = Message()
        ..from = const Address(_senderEmail, 'Nurse Tracking App')
        ..recipients.add(_managerEmail)
        ..subject = 'New Injury Report - $severity Severity'
        ..html = _buildEmailHtml(
          date: date,
          injuredPerson: injuredPerson,
          reportingEmployee: reportingEmployee,
          location: location,
          description: description,
          severity: severity,
          status: status,
        );

      // Attach signature image if provided
      if (signatureImage != null) {
        message.attachments.add(
          StreamAttachment(
            Stream.value(signatureImage),
            'signature.png',
          ),
        );
      }

      // Send the email
      final sendReport = await send(message, smtpServer);
      print('Email sent successfully: ${sendReport.toString()}');
      return true;
    } catch (e) {
      print('Failed to send email: $e');
      return false;
    }
  }

  /// Builds the HTML content for the injury report email
  static String _buildEmailHtml({
    required String date,
    required String injuredPerson,
    required String reportingEmployee,
    required String location,
    required String description,
    required String severity,
    required String status,
  }) {
    return '''
    <!DOCTYPE html>
    <html>
    <head>
        <meta charset="UTF-8">
        <title>Injury Report</title>
        <style>
            body { font-family: Arial, sans-serif; line-height: 1.6; color: #333; }
            .container { max-width: 600px; margin: 0 auto; padding: 20px; }
            .header { background-color: #f8f9fa; padding: 20px; border-radius: 8px; margin-bottom: 20px; }
            .severity-high { background-color: #ffebee; border-left: 4px solid #f44336; }
            .severity-critical { background-color: #ffebee; border-left: 4px solid #d32f2f; }
            .severity-moderate { background-color: #fff3e0; border-left: 4px solid #ff9800; }
            .severity-low { background-color: #e8f5e8; border-left: 4px solid #4caf50; }
            .field { margin-bottom: 15px; }
            .label { font-weight: bold; color: #555; }
            .value { margin-top: 5px; padding: 8px; background-color: #f8f9fa; border-radius: 4px; }
            .footer { margin-top: 30px; padding-top: 20px; border-top: 1px solid #eee; font-size: 12px; color: #666; }
        </style>
    </head>
    <body>
        <div class="container">
            <div class="header">
                <h2>🚨 New Injury Report</h2>
                <p>This is an automated notification from the Nurse Tracking App.</p>
            </div>
            
            <div class="field">
                <div class="label">📅 Date of Incident:</div>
                <div class="value">$date</div>
            </div>
            
            <div class="field">
                <div class="label">👤 Injured Person:</div>
                <div class="value">$injuredPerson</div>
            </div>
            
            <div class="field">
                <div class="label">📝 Reported By:</div>
                <div class="value">$reportingEmployee</div>
            </div>
            
            <div class="field">
                <div class="label">📍 Location:</div>
                <div class="value">$location</div>
            </div>
            
            <div class="field">
                <div class="label">📋 Description:</div>
                <div class="value">$description</div>
            </div>
            
            <div class="field">
                <div class="label">⚠️ Severity:</div>
                <div class="value severity-$severity.toLowerCase()">$severity</div>
            </div>
            
            <div class="field">
                <div class="label">📊 Status:</div>
                <div class="value">$status</div>
            </div>
            
            <div class="footer">
                <p>This report was automatically generated by the Nurse Tracking App.</p>
                <p>Please review and take appropriate action as needed.</p>
            </div>
        </div>
    </body>
    </html>
    ''';
  }
}
