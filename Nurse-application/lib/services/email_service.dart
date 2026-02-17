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
      await send(message, smtpServer);
      // print('Email sent successfully: ${sendReport.toString()}');
      return true;
    } catch (e) {
      // print('Failed to send email: $e');
      return false;
    }
  }

  /// Builds the HTML content for the injury report email (legacy method)
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

  /// Sends a hazard/near miss report email to the supervisor
  static Future<bool> sendHazardReportEmail({
    required String incidentDate,
    required String incidentTime,
    required String location,
    required String hazardRating,
    required List<String> hazardTypes,
    required String hazardStatement,
    required String immediateAction,
    // New fields
    String? telephone,
    String? supervisor,
    String? dateReported,
    String? timeReported,
    String? reasonForDelay,
    String? involvedWorkers,
    String? involvedClients,
    String? involvedOthers,
    String? witnessName,
    String? witnessRemarks,
    String? signatureUrl,
    Uint8List? signatureImage,
  }) async {
    try {
      final smtpServer = SmtpServer(
        _smtpServer,
        port: _smtpPort,
        username: _senderEmail,
        password: _senderPassword,
        allowInsecure: false,
        ignoreBadCertificate: false,
      );

      final message = Message()
        ..from = const Address(_senderEmail, 'Nurse Tracking App')
        ..recipients.add(_managerEmail)
        ..subject = 'Hazard / Near Miss Report Submitted'
        ..html = _buildHazardReportHtml(
          incidentDate: incidentDate,
          incidentTime: incidentTime,
          location: location,
          hazardRating: hazardRating,
          hazardTypes: hazardTypes,
          hazardStatement: hazardStatement,
          immediateAction: immediateAction,
          telephone: telephone,
          supervisor: supervisor,
          dateReported: dateReported,
          timeReported: timeReported,
          reasonForDelay: reasonForDelay,
          involvedWorkers: involvedWorkers,
          involvedClients: involvedClients,
          involvedOthers: involvedOthers,
          witnessName: witnessName,
          witnessRemarks: witnessRemarks,
          signatureUrl: signatureUrl,
        );

      if (signatureImage != null) {
        message.attachments.add(
          StreamAttachment(
            Stream.value(signatureImage),
            'signature.png',
          ),
        );
      }

      await send(message, smtpServer);
      // print('✅ Hazard report email sent successfully');
      return true;
    } catch (e) {
      // print('❌ Failed to send hazard report email: $e');
      return false;
    }
  }

  static String _buildHazardReportHtml({
    required String incidentDate,
    required String incidentTime,
    required String location,
    required String hazardRating,
    required List<String> hazardTypes,
    required String hazardStatement,
    required String immediateAction,
    String? telephone,
    String? supervisor,
    String? dateReported,
    String? timeReported,
    String? reasonForDelay,
    String? involvedWorkers,
    String? involvedClients,
    String? involvedOthers,
    String? witnessName,
    String? witnessRemarks,
    String? signatureUrl,
  }) {
    final hazardTypesStr = hazardTypes.join(', ');
    final ratingClass =
        hazardRating == 'SERIOUS' ? 'severity-high' : 'severity-low';

    return '''
    <!DOCTYPE html>
    <html>
    <head>
        <meta charset="UTF-8">
        <title>Hazard / Near Miss Report</title>
        <style>
            body { font-family: Arial, sans-serif; line-height: 1.6; color: #333; }
            .container { max-width: 600px; margin: 0 auto; padding: 20px; }
            .header { background-color: #fff3e0; padding: 20px; border-radius: 8px; margin-bottom: 20px; }
            .section-title { background-color: #666; color: white; padding: 5px 10px; font-weight: bold; margin-top: 20px; border-radius: 4px; }
            .severity-high { background-color: #ffebee; border-left: 4px solid #f44336; }
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
                <h2>⚠️ Hazard / Near Miss Report</h2>
                <p>This is an automated notification from the Nurse Tracking App.</p>
            </div>
            
            <div class="section-title">PART 1: REPORT COMPLETED BY</div>
            <div class="field">
                <div class="label">📞 Telephone:</div>
                <div class="value">${telephone ?? 'N/A'}</div>
            </div>
            <div class="field">
                <div class="label">👤 Supervisor Reported To:</div>
                <div class="value">${supervisor ?? 'N/A'}</div>
            </div>
            <div class="field">
                <div class="label">📅 Date Reported:</div>
                <div class="value">${dateReported ?? 'N/A'}</div>
            </div>
            <div class="field">
                <div class="label">🕒 Time Reported:</div>
                <div class="value">${timeReported ?? 'N/A'}</div>
            </div>
            <div class="field">
                <div class="label">📅 Incident Date:</div>
                <div class="value">$incidentDate</div>
            </div>
            <div class="field">
                <div class="label">🕒 Incident Time:</div>
                <div class="value">$incidentTime</div>
            </div>
            <div class="field">
                <div class="label">📍 Location of Incident:</div>
                <div class="value">$location</div>
            </div>
             <div class="field">
                <div class="label">⏳ Reason for Delay:</div>
                <div class="value">${reasonForDelay ?? 'N/A'}</div>
            </div>
            
            <div class="section-title">PART 2: INDIVIDUALS INVOLVED</div>
             <div class="field">
                <div class="label">Workers:</div>
                <div class="value">${involvedWorkers ?? 'None'}</div>
            </div>
             <div class="field">
                <div class="label">Clients:</div>
                <div class="value">${involvedClients ?? 'None'}</div>
            </div>
             <div class="field">
                <div class="label">Others:</div>
                <div class="value">${involvedOthers ?? 'None'}</div>
            </div>

            <div class="section-title">PART 3 & 4: RATING & TYPE</div>
            <div class="field">
                <div class="label">⚠️ Hazard Rating:</div>
                <div class="value $ratingClass">${hazardRating.replaceAll('_', ' ')}</div>
            </div>
            
            <div class="field">
                <div class="label">🔍 Hazard Types:</div>
                <div class="value">$hazardTypesStr</div>
            </div>
            
            <div class="section-title">PART 5: STATEMENT & ACTION</div>
            <div class="field">
                <div class="label">📋 Hazard Statement:</div>
                <div class="value">$hazardStatement</div>
            </div>
            
            <div class="field">
                <div class="label">✅ Immediate Action Taken:</div>
                <div class="value">$immediateAction</div>
            </div>

            <div class="section-title">PART 6: WITNESS REMARKS</div>
             <div class="field">
                <div class="label">Witness Name:</div>
                <div class="value">${witnessName ?? 'N/A'}</div>
            </div>
             <div class="field">
                <div class="label">Remarks:</div>
                <div class="value">${witnessRemarks ?? 'N/A'}</div>
            </div>

            ${signatureUrl != null ? '<div class="field"><div class="label">✍️ Signature URL:</div><div class="value"><a href="$signatureUrl">View Signature</a></div></div>' : ''}
            
            <div class="footer">
                <p>This report was automatically generated by the Nurse Tracking App.</p>
                <p>Please review and take appropriate action as needed.</p>
            </div>
        </div>
    </body>
    </html>
    ''';
  }

  /// Sends an incident report email to the supervisor
  static Future<bool> sendIncidentReportEmail({
    required String incidentDate,
    required String incidentTime,
    required String location,
    required String description,
    required String sequenceOfEvents,
    required String immediateActions,
    required String clientCondition,
    required bool medicalAttentionRequired,
    // New fields
    String? jobTitle,
    String? telephone,
    String? email,
    String? supervisorReportedTo,
    String? dateReported,
    String? timeReported,
    String? workersInvolved,
    String? clientsInvolved,
    String? othersInvolved,
    String? witnessName,
    String? witnessTitle,
    String? witnessContact,
    String? whoReported,
    String? whatStated,
    String? personalObs,
    String? painDiscomfort,
    String? injuryDetails,
    String? hazards,
    String? whoInformed,
    String? signatureUrl,
    Uint8List? signatureImage,
  }) async {
    try {
      final smtpServer = SmtpServer(
        _smtpServer,
        port: _smtpPort,
        username: _senderEmail,
        password: _senderPassword,
        allowInsecure: false,
        ignoreBadCertificate: false,
      );

      final message = Message()
        ..from = const Address(_senderEmail, 'Nurse Tracking App')
        ..recipients.add(_managerEmail)
        ..subject = 'Incident Report Submitted'
        ..html = _buildIncidentReportHtml(
          incidentDate: incidentDate,
          incidentTime: incidentTime,
          location: location,
          description: description,
          sequenceOfEvents: sequenceOfEvents,
          immediateActions: immediateActions,
          clientCondition: clientCondition,
          medicalAttentionRequired: medicalAttentionRequired,
          jobTitle: jobTitle,
          telephone: telephone,
          email: email,
          supervisorReportedTo: supervisorReportedTo,
          dateReported: dateReported,
          timeReported: timeReported,
          workersInvolved: workersInvolved,
          clientsInvolved: clientsInvolved,
          othersInvolved: othersInvolved,
          witnessName: witnessName,
          witnessTitle: witnessTitle,
          witnessContact: witnessContact,
          whoReported: whoReported,
          whatStated: whatStated,
          personalObs: personalObs,
          painDiscomfort: painDiscomfort,
          injuryDetails: injuryDetails,
          hazards: hazards,
          whoInformed: whoInformed,
          signatureUrl: signatureUrl,
        );

      if (signatureImage != null) {
        message.attachments.add(
          StreamAttachment(
            Stream.value(signatureImage),
            'signature.png',
          ),
        );
      }

      await send(message, smtpServer);
      // print('✅ Incident report email sent successfully');
      return true;
    } catch (e) {
      // print('❌ Failed to send incident report email: $e');
      return false;
    }
  }

  static String _buildIncidentReportHtml({
    required String incidentDate,
    required String incidentTime,
    required String location,
    required String description,
    required String sequenceOfEvents,
    required String immediateActions,
    required String clientCondition,
    required bool medicalAttentionRequired,
    String? jobTitle,
    String? telephone,
    String? email,
    String? supervisorReportedTo,
    String? dateReported,
    String? timeReported,
    String? workersInvolved,
    String? clientsInvolved,
    String? othersInvolved,
    String? witnessName,
    String? witnessTitle,
    String? witnessContact,
    String? whoReported,
    String? whatStated,
    String? personalObs,
    String? painDiscomfort,
    String? injuryDetails,
    String? hazards,
    String? whoInformed,
    String? signatureUrl,
  }) {
    return '''
    <!DOCTYPE html>
    <html>
    <head>
        <meta charset="UTF-8">
        <title>Incident Report</title>
        <style>
            body { font-family: Arial, sans-serif; line-height: 1.6; color: #333; }
            .container { max-width: 600px; margin: 0 auto; padding: 20px; }
            .header { background-color: #e3f2fd; padding: 20px; border-radius: 8px; margin-bottom: 20px; }
            .section-title { background-color: #666; color: white; padding: 5px 10px; font-weight: bold; margin-top: 20px; border-radius: 4px; }
            .field { margin-bottom: 15px; }
            .label { font-weight: bold; color: #555; }
            .value { margin-top: 5px; padding: 8px; background-color: #f8f9fa; border-radius: 4px; }
            .alert { background-color: #ffebee; border-left: 4px solid #f44336; padding: 10px; margin: 15px 0; }
            .footer { margin-top: 30px; padding-top: 20px; border-top: 1px solid #eee; font-size: 12px; color: #666; }
        </style>
    </head>
    <body>
        <div class="container">
            <div class="header">
                <h2>📋 Incident Report</h2>
                <p>This is an automated notification from the Nurse Tracking App.</p>
            </div>
            
            <div class="section-title">PART 1: REPORT COMPLETED BY</div>
            <div class="field"><div class="label">Job Title:</div><div class="value">${jobTitle ?? 'N/A'}</div></div>
            <div class="field"><div class="label">Telephone:</div><div class="value">${telephone ?? 'N/A'}</div></div>
            <div class="field"><div class="label">Email:</div><div class="value">${email ?? 'N/A'}</div></div>
            <div class="field"><div class="label">Work/Incident Location:</div><div class="value">$location</div></div>
            <div class="field"><div class="label">Supervisor Reported To:</div><div class="value">${supervisorReportedTo ?? 'N/A'}</div></div>
            <div class="field"><div class="label">Date Reported:</div><div class="value">${dateReported ?? 'N/A'}</div></div>
            <div class="field"><div class="label">Time Reported:</div><div class="value">${timeReported ?? 'N/A'}</div></div>

            <div class="section-title">PART 2: INDIVIDUALS INVOLVED</div>
            <div class="field"><div class="label">Workers:</div><div class="value">${workersInvolved ?? 'None'}</div></div>
            <div class="field"><div class="label">Clients:</div><div class="value">${clientsInvolved ?? 'None'}</div></div>
            <div class="field"><div class="label">Others:</div><div class="value">${othersInvolved ?? 'None'}</div></div>
            <div class="field">
                <div class="label">Witness Info:</div>
                <div class="value">
                    Name: ${witnessName ?? 'N/A'}<br>
                    Title: ${witnessTitle ?? 'N/A'}<br>
                    Contact: ${witnessContact ?? 'N/A'}
                </div>
            </div>

            <div class="section-title">PART 3: STATEMENT OF INCIDENT</div>
            <div class="field"><div class="label">Incident Date:</div><div class="value">$incidentDate</div></div>
            <div class="field"><div class="label">Incident Time:</div><div class="value">$incidentTime</div></div>
            
            <div class="field"><div class="label">What was the incident?</div><div class="value">$description</div></div>
            <div class="field"><div class="label">Who reported it?</div><div class="value">${whoReported ?? 'N/A'}</div></div>
            <div class="field"><div class="label">Exact Statement:</div><div class="value">${whatStated ?? 'N/A'}</div></div>
            <div class="field"><div class="label">Personal Observation:</div><div class="value">${personalObs ?? 'N/A'}</div></div>
            <div class="field"><div class="label">Sequence of Events:</div><div class="value">$sequenceOfEvents</div></div>
            
            <div class="section-title">CONDITION & ACTIONS</div>
            <div class="field"><div class="label">Expressed Pain/Discomfort?</div><div class="value">${painDiscomfort ?? 'N/A'}</div></div>
            <div class="field"><div class="label">Client Condition:</div><div class="value">$clientCondition</div></div>
            
            ${medicalAttentionRequired ? '<div class="alert">🚨 <strong>Medical Attention Required</strong><br>Details: ${injuryDetails ?? 'N/A'}</div>' : ''}
            
            <div class="field"><div class="label">Environmental Hazards?</div><div class="value">${hazards ?? 'N/A'}</div></div>
            <div class="field"><div class="label">Immediate Actions:</div><div class="value">$immediateActions</div></div>
            <div class="field"><div class="label">Who Informed?</div><div class="value">${whoInformed ?? 'N/A'}</div></div>

            ${signatureUrl != null ? '<div class="field"><div class="label">✍️ Signature URL:</div><div class="value"><a href="$signatureUrl">View Signature</a></div></div>' : ''}
            
            <div class="footer">
                <p>This report was automatically generated by the Nurse Tracking App.</p>
                <p>Please review and take appropriate action as needed.</p>
            </div>
        </div>
    </body>
    </html>
    ''';
  }

  /// Sends an employee injury/illness report email to coordinator
  static Future<bool> sendInjuryReportEmail({
    required String injuryDate,
    required String injuryTime,
    required String program,
    required String description,
    required List<String> bodyParts,
    required bool medicalAttentionRequired,
    // New fields
    String? supervisorReportedTo,
    String? dateReported,
    String? employeeName,
    String? employeePhone,
    String? timeLeftWork,
    String? location,
    String? clientInvolved,
    String? witnessName,
    String? hcpDetails,
    Uint8List? signatureImage,
  }) async {
    try {
      final smtpServer = SmtpServer(
        _smtpServer,
        port: _smtpPort,
        username: _senderEmail,
        password: _senderPassword,
        allowInsecure: false,
        ignoreBadCertificate: false,
      );

      final message = Message()
        ..from = const Address(_senderEmail, 'Nurse Tracking App')
        ..recipients.add(_managerEmail)
        ..subject = 'Employee Injury Report Submitted'
        ..html = _buildInjuryReportHtml(
          injuryDate: injuryDate,
          injuryTime: injuryTime,
          program: program,
          description: description,
          bodyParts: bodyParts,
          medicalAttentionRequired: medicalAttentionRequired,
          supervisorReportedTo: supervisorReportedTo,
          dateReported: dateReported,
          employeeName: employeeName,
          employeePhone: employeePhone,
          timeLeftWork: timeLeftWork,
          location: location,
          clientInvolved: clientInvolved,
          witnessName: witnessName,
          hcpDetails: hcpDetails,
        );

      if (signatureImage != null) {
        message.attachments.add(
          StreamAttachment(
            Stream.value(signatureImage),
            'signature.png',
          ),
        );
      }

      await send(message, smtpServer);
      // print('✅ Injury report email sent successfully');
      return true;
    } catch (e) {
      // print('❌ Failed to send injury report email: $e');
      return false;
    }
  }

  static String _buildInjuryReportHtml({
    required String injuryDate,
    required String injuryTime,
    required String program,
    required String description,
    required List<String> bodyParts,
    required bool medicalAttentionRequired,
    String? supervisorReportedTo,
    String? dateReported,
    String? employeeName,
    String? employeePhone,
    String? timeLeftWork,
    String? location,
    String? clientInvolved,
    String? witnessName,
    String? hcpDetails,
  }) {
    final bodyPartsStr = bodyParts.join(', ');

    return '''
    <!DOCTYPE html>
    <html>
    <head>
        <meta charset="UTF-8">
        <title>Employee Injury Report</title>
        <style>
            body { font-family: Arial, sans-serif; line-height: 1.6; color: #333; }
            .container { max-width: 600px; margin: 0 auto; padding: 20px; }
            .header { background-color: #ffcdd2; padding: 20px; border-radius: 8px; margin-bottom: 20px; }
            .section-title { background-color: #555; color: white; padding: 5px 10px; font-weight: bold; margin-top: 20px; border-radius: 4px; }
            .field { margin-bottom: 15px; }
            .label { font-weight: bold; color: #555; }
            .value { margin-top: 5px; padding: 8px; background-color: #f8f9fa; border-radius: 4px; }
            .alert { background-color: #ffebee; border-left: 4px solid #f44336; padding: 10px; margin: 15px 0; }
            .footer { margin-top: 30px; padding-top: 20px; border-top: 1px solid #eee; font-size: 12px; color: #666; }
        </style>
    </head>
    <body>
        <div class="container">
            <div class="header">
                <h2>🤕 Employee Injury Report</h2>
                <p>This is an automated notification from the Nurse Tracking App.</p>
            </div>
            
            <div class="section-title">PART 1: REPORT COMPLETED BY</div>
            <div class="field"><div class="label">Reported To:</div><div class="value">${supervisorReportedTo ?? 'N/A'}</div></div>
            <div class="field"><div class="label">Date Reported:</div><div class="value">${dateReported ?? 'N/A'}</div></div>

            <div class="section-title">PART 2: PERSONAL DATA</div>
            <div class="field"><div class="label">Employee Name:</div><div class="value">${employeeName ?? 'N/A'}</div></div>
            <div class="field"><div class="label">Phone:</div><div class="value">${employeePhone ?? 'N/A'}</div></div>
            ${medicalAttentionRequired ? '<div class="alert">🚨 <strong>Medical Attention Required</strong></div>' : ''}

            <div class="section-title">PART 3 & 4: INJURY DETAILS</div>
            <div class="field"><div class="label">Injury Date:</div><div class="value">$injuryDate</div></div>
            <div class="field"><div class="label">Injury Time:</div><div class="value">$injuryTime</div></div>
            <div class="field"><div class="label">Time Left Work:</div><div class="value">${timeLeftWork ?? 'N/A'}</div></div>
            <div class="field"><div class="label">Program:</div><div class="value">$program</div></div>
            <div class="field"><div class="label">Location:</div><div class="value">${location ?? 'N/A'}</div></div>
            <div class="field"><div class="label">Client Involved:</div><div class="value">${clientInvolved ?? 'N/A'}</div></div>
            <div class="field"><div class="label">Injured Body Parts:</div><div class="value">$bodyPartsStr</div></div>
            
            <div class="section-title">PART 5: DESCRIPTION</div>
            <div class="field"><div class="label">Description:</div><div class="value">$description</div></div>
            
            <div class="section-title">PART 6: WITNESS</div>
            <div class="field"><div class="label">Witness Name:</div><div class="value">${witnessName ?? 'N/A'}</div></div>
            
            ${hcpDetails != null ? '<div class="section-title">PART 7: HCP DETAILS</div><div class="field"><div class="value"><pre>$hcpDetails</pre></div></div>' : ''}
            
            <div class="footer">
                <p>This report was automatically generated by the Nurse Tracking App.</p>
                <p>Please review and take appropriate action as needed.</p>
            </div>
        </div>
    </body>
    </html>
    ''';
  }

  /// Sends a shift change request email
  static Future<bool> sendShiftChangeRequestEmail({
    required String requestType,
    required String clientName,
    required String shiftDate,
    required String shiftTime,
    required String reason,
    required String employeeName,
    String? signatureUrl,
    Uint8List? signatureImage,
  }) async {
    try {
      final smtpServer = SmtpServer(
        _smtpServer,
        port: _smtpPort,
        username: _senderEmail,
        password: _senderPassword,
        allowInsecure: false,
        ignoreBadCertificate: false,
      );

      final message = Message()
        ..from = const Address(_senderEmail, 'Nurse Tracking App')
        ..recipients.add(_managerEmail)
        ..subject = 'Shift Change Request: $requestType'
        ..html = _buildShiftChangeRequestHtml(
          requestType: requestType,
          clientName: clientName,
          shiftDate: shiftDate,
          shiftTime: shiftTime,
          reason: reason,
          employeeName: employeeName,
          signatureUrl: signatureUrl,
        );

      if (signatureImage != null) {
        message.attachments.add(
          StreamAttachment(
            Stream.value(signatureImage),
            'signature.png',
          ),
        );
      }

      await send(message, smtpServer);
      return true;
    } catch (e) {
      return false;
    }
  }

  static String _buildShiftChangeRequestHtml({
    required String requestType,
    required String clientName,
    required String shiftDate,
    required String shiftTime,
    required String reason,
    required String employeeName,
    String? signatureUrl,
  }) {
    return '''
    <!DOCTYPE html>
    <html>
    <head>
        <meta charset="UTF-8">
        <title>Shift Change Request</title>
        <style>
            body { font-family: Arial, sans-serif; line-height: 1.6; color: #333; }
            .container { max-width: 600px; margin: 0 auto; padding: 20px; }
            .header { background-color: #e0f7fa; padding: 20px; border-radius: 8px; margin-bottom: 20px; }
            .field { margin-bottom: 15px; }
            .label { font-weight: bold; color: #555; }
            .value { margin-top: 5px; padding: 8px; background-color: #f8f9fa; border-radius: 4px; }
            .footer { margin-top: 30px; padding-top: 20px; border-top: 1px solid #eee; font-size: 12px; color: #666; }
        </style>
    </head>
    <body>
        <div class="container">
            <div class="header">
                <h2>🔄 Shift Change Request</h2>
                <p>This is an automated notification from the Nurse Tracking App.</p>
            </div>
            
            <div class="field"><div class="label">Request Type:</div><div class="value">$requestType</div></div>
            <div class="field"><div class="label">Employee:</div><div class="value">$employeeName</div></div>
            <div class="field"><div class="label">Client:</div><div class="value">$clientName</div></div>
            <div class="field"><div class="label">Shift Date:</div><div class="value">$shiftDate</div></div>
            <div class="field"><div class="label">Shift Time:</div><div class="value">$shiftTime</div></div>
            <div class="field"><div class="label">Reason:</div><div class="value">$reason</div></div>
            
            ${signatureUrl != null ? '<div class="field"><div class="label">✍️ Signature URL:</div><div class="value"><a href="$signatureUrl">View Signature</a></div></div>' : ''}
            
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
