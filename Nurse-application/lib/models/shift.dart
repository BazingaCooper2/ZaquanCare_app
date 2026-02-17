import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'patient.dart';

class Shift {
  final int shiftId;
  final int? clientId;
  final int? empId;
  final String? date;
  final String? shiftStartTime;
  final String? shiftEndTime;
  final String? taskId;
  final String? skills;
  final String? serviceInstructions;
  final String? tags;
  final String? forms;
  final String? shiftStatus;
  final String? shiftProgressNote;
  final Patient? patient;
  final String? useServiceDuration;
  final String? clientName;
  final String? clientLocation;
  final String? clientServiceType;

  Shift({
    required this.shiftId,
    this.clientId,
    this.empId,
    this.date,
    this.shiftStartTime,
    this.shiftEndTime,
    this.taskId,
    this.skills,
    this.serviceInstructions,
    this.tags,
    this.forms,
    this.shiftStatus,
    this.shiftProgressNote,
    this.patient,
    this.useServiceDuration,
    this.clientName,
    this.clientLocation,
    this.clientServiceType,
  });

  factory Shift.fromJson(Map<String, dynamic> json) {
    // Debug logging to see the structure
    debugPrint('🔍 Parsing Shift JSON: ${json.keys}');
    debugPrint('🔍 Client data: ${json['client']}');

    final clientName = json['client']?['name'] ?? json['client_name'];
    final clientLocation =
        json['client']?['patient_location'] ?? json['client_location'];
    final clientServiceType =
        json['client']?['service_type'] ?? json['client_service_type'];

    debugPrint('🔍 Parsed clientName: $clientName');
    debugPrint('🔍 Parsed clientLocation: $clientLocation');

    return Shift(
      shiftId: json['shift_id'],
      clientId: json['client_id'],
      empId: json['emp_id'],
      date: json['date'],
      shiftStartTime: json['shift_start_time'],
      shiftEndTime: json['shift_end_time'],
      taskId: json['task_id'],
      skills: json['skills'],
      serviceInstructions: json['service_instructions'],
      tags: json['tags'],
      forms: json['forms'],
      shiftStatus: json['shift_status'],
      shiftProgressNote: json['shift_progress_note'],
      patient: null, // No patient join for now
      useServiceDuration: json['use_service_duration'],
      clientName: clientName,
      clientLocation: clientLocation,
      clientServiceType: clientServiceType,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'shift_id': shiftId,
      'client_id': clientId,
      'emp_id': empId,
      'date': date,
      'shift_start_time': shiftStartTime,
      'shift_end_time': shiftEndTime,
      'task_id': taskId,
      'skills': skills,
      'service_instructions': serviceInstructions,
      'tags': tags,
      'forms': forms,
      'shift_status': shiftStatus,
      'shift_progress_note': shiftProgressNote,
      'use_service_duration': useServiceDuration,
    };
  }

  Shift copyWith({
    int? shiftId,
    int? clientId,
    int? empId,
    String? date,
    String? shiftStartTime,
    String? shiftEndTime,
    String? taskId,
    String? skills,
    String? serviceInstructions,
    String? tags,
    String? forms,
    String? shiftStatus,
    String? shiftProgressNote,
    Patient? patient,
    String? useServiceDuration,
    String? clientName,
    String? clientLocation,
  }) {
    return Shift(
      shiftId: shiftId ?? this.shiftId,
      clientId: clientId ?? this.clientId,
      empId: empId ?? this.empId,
      date: date ?? this.date,
      shiftStartTime: shiftStartTime ?? this.shiftStartTime,
      shiftEndTime: shiftEndTime ?? this.shiftEndTime,
      taskId: taskId ?? this.taskId,
      skills: skills ?? this.skills,
      serviceInstructions: serviceInstructions ?? this.serviceInstructions,
      tags: tags ?? this.tags,
      forms: forms ?? this.forms,
      shiftStatus: shiftStatus ?? this.shiftStatus,
      shiftProgressNote: shiftProgressNote ?? this.shiftProgressNote,
      patient: patient ?? this.patient,
      useServiceDuration: useServiceDuration ?? this.useServiceDuration,
      clientName: clientName ?? this.clientName,
      clientLocation: clientLocation ?? this.clientLocation,
    );
  }

  String get statusDisplayText {
    final normalized = shiftStatus?.toLowerCase().replaceAll(' ', '_');
    switch (normalized) {
      case 'scheduled':
        return 'Scheduled';
      case 'in_progress':
        return 'In Progress';
      case 'completed':
        return 'Completed';
      case 'cancelled':
        return 'Cancelled';
      default:
        return shiftStatus ?? 'Unknown';
    }
  }

  Color get statusColor {
    final normalized = shiftStatus?.toLowerCase().replaceAll(' ', '_');
    switch (normalized) {
      case 'scheduled':
        return Colors.orange;
      case 'in_progress':
        return Colors.blue;
      case 'completed':
        return Colors.green;
      case 'cancelled':
        return Colors.red;
      default:
        return Colors.grey;
    }
  }

  // Helper method to parse various time formats
  static DateTime? _parseTimeAny(String? input) {
    if (input == null || input.isEmpty) return null;
    try {
      // 1. Try ISO8601 (e.g., "2026-01-22T14:45:00")
      return DateTime.parse(input);
    } catch (_) {
      // 2. Try HH:mm:ss or HH:mm (e.g., "14:45:00")
      try {
        final parts = input.split(':');
        if (parts.length >= 2) {
          final now = DateTime.now();
          return DateTime(
            now.year,
            now.month,
            now.day,
            int.parse(parts[0]),
            int.parse(parts[1]),
          );
        }
      } catch (e) {
        debugPrint('Err parsing time: $input');
      }
    }
    return null;
  }

  // Helper method to calculate duration in hours
  double? get durationHours {
    final start = _parseTimeAny(shiftStartTime);
    final end = _parseTimeAny(shiftEndTime);

    if (start == null || end == null) return null;

    // If end is before start in time-only mode, mostly doesn't happen with full dates.
    // If it does (night shift), logic needs to handle date crossing, but usually full ISO handles it.
    final diff = end.difference(start);
    return diff.inMinutes / 60.0;
  }

  // Helper method to calculate overtime hours
  double? get overtimeHours {
    final duration = durationHours;
    if (duration == null) return null;
    return duration > 8 ? duration - 8 : 0;
  }

  // Helper method to convert 24hr time OR ISO time to 12hr AM/PM format
  static String formatTime12Hour(String? timeInput) {
    if (timeInput == null || timeInput.isEmpty) return '';

    try {
      final dateTime = _parseTimeAny(timeInput);
      if (dateTime != null) {
        return DateFormat('h:mm a').format(dateTime); // e.g. 2:45 PM
      }
      return timeInput;
    } catch (_) {
      return timeInput;
    }
  }

  // Get formatted start time (12-hour format)
  String get formattedStartTime => formatTime12Hour(shiftStartTime);

  // Get formatted end time (12-hour format)
  String get formattedEndTime => formatTime12Hour(shiftEndTime);

  // Get formatted time range (e.g., "9:00 AM - 5:00 PM")
  String get formattedTimeRange {
    if (shiftStartTime == null || shiftEndTime == null) {
      return 'Time not set';
    }
    return '$formattedStartTime - $formattedEndTime';
  }
}
