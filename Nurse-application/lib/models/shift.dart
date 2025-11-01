import 'package:flutter/material.dart';
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
  });

  factory Shift.fromJson(Map<String, dynamic> json) {
    return Shift(
      shiftId: json['shift_id'],
      clientId: json['client_id'],
      empId: json['emp_id'],
      date: json['date'],
      shiftStartTime: json['shift_start_time'],
      shiftEndTime: json['shift_end_time'],
      taskId: json['Task_ID'],
      skills: json['Skills'],
      serviceInstructions: json['Service_Instructions'],
      tags: json['Tags'],
      forms: json['Forms'],
      shiftStatus: json['shift_status'],
      shiftProgressNote: json['shift_progress_note'],
      patient: null, // No patient join for now
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
      'Task_ID': taskId,
      'Skills': skills,
      'Service_Instructions': serviceInstructions,
      'Tags': tags,
      'Forms': forms,
      'shift_status': shiftStatus,
      'shift_progress_note': shiftProgressNote,
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
    );
  }

  String get statusDisplayText {
    switch (shiftStatus) {
      case 'scheduled':
        return 'Scheduled';
      case 'in_progress':
        return 'In Progress';
      case 'completed':
        return 'Completed';
      case 'cancelled':
        return 'Cancelled';
      default:
        return 'Unknown';
    }
  }

  Color get statusColor {
    switch (shiftStatus) {
      case 'scheduled':
        return Colors.blue;
      case 'in_progress':
        return Colors.orange;
      case 'completed':
        return Colors.green;
      case 'cancelled':
        return Colors.red;
      default:
        return Colors.grey;
    }
  }

  // Helper method to calculate duration in hours
  double? get durationHours {
    if (shiftStartTime == null || shiftEndTime == null) return null;

    try {
      final startParts = shiftStartTime!.split(':');
      final endParts = shiftEndTime!.split(':');

      final startHour = int.parse(startParts[0]);
      final startMinute = int.parse(startParts[1]);
      final endHour = int.parse(endParts[0]);
      final endMinute = int.parse(endParts[1]);

      final startMinutes = startHour * 60 + startMinute;
      final endMinutes = endHour * 60 + endMinute;

      final durationMinutes = endMinutes - startMinutes;
      return durationMinutes / 60.0;
    } catch (e) {
      return null;
    }
  }

  // Helper method to calculate overtime hours
  double? get overtimeHours {
    final duration = durationHours;
    if (duration == null) return null;
    return duration > 8 ? duration - 8 : 0;
  }
}
