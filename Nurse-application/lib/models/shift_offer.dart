/// Model for shift offers received via WebSocket
class ShiftOffer {
  final int shiftId;
  final String date;
  final String startTime;
  final String endTime;
  final String? locationName;
  final String? clientName;
  final String? description;
  final String? serviceType;
  final DateTime receivedAt;

  ShiftOffer({
    required this.shiftId,
    required this.date,
    required this.startTime,
    required this.endTime,
    this.locationName,
    this.clientName,
    this.description,
    this.serviceType,
    DateTime? receivedAt,
  }) : receivedAt = receivedAt ?? DateTime.now();

  /// Parse shift offer from WebSocket JSON message
  factory ShiftOffer.fromJson(Map<String, dynamic> json) {
    return ShiftOffer(
      shiftId: json['shift_id'] as int,
      date: json['date'] as String,
      startTime: json['start_time'] as String,
      endTime: json['end_time'] as String,
      locationName: json['location_name'] as String?,
      clientName: json['client_name'] as String?,
      description: json['description'] as String?,
      serviceType: json['service_type'] as String?,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'shift_id': shiftId,
      'date': date,
      'start_time': startTime,
      'end_time': endTime,
      'location_name': locationName,
      'client_name': clientName,
      'description': description,
      'service_type': serviceType,
    };
  }

  /// Format date and time for display
  String get displayDateTime {
    return '$date $startTime - $endTime';
  }

  /// Get location or default
  String get displayLocation {
    return locationName ?? 'Location not specified';
  }
}
