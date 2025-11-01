class TimeLog {
  final String id;
  final int empId;
  final String? scheduleId;
  final DateTime? clockInTime;
  final DateTime? clockOutTime;
  final double? clockInLatitude;
  final double? clockInLongitude;
  final double? clockOutLatitude;
  final double? clockOutLongitude;
  final String? clockInAddress;
  final String? clockOutAddress;
  final double? totalHours;
  final DateTime createdAt;
  final DateTime updatedAt;

  TimeLog({
    required this.id,
    required this.empId,
    required this.scheduleId,
    this.clockInTime,
    this.clockOutTime,
    this.clockInLatitude,
    this.clockInLongitude,
    this.clockOutLatitude,
    this.clockOutLongitude,
    this.clockInAddress,
    this.clockOutAddress,
    this.totalHours,
    required this.createdAt,
    required this.updatedAt,
  });

  factory TimeLog.fromJson(Map<String, dynamic> json) {
    return TimeLog(
      id: json['id'],
      empId: json['emp_id'],
      scheduleId: json['schedule_id'],
      clockInTime: json['clock_in_time'] != null
          ? DateTime.parse(json['clock_in_time'])
          : null,
      clockOutTime: json['clock_out_time'] != null
          ? DateTime.parse(json['clock_out_time'])
          : null,
      clockInLatitude: json['clock_in_latitude']?.toDouble(),
      clockInLongitude: json['clock_in_longitude']?.toDouble(),
      clockOutLatitude: json['clock_out_latitude']?.toDouble(),
      clockOutLongitude: json['clock_out_longitude']?.toDouble(),
      clockInAddress: json['clock_in_address'],
      clockOutAddress: json['clock_out_address'],
      totalHours: json['total_hours']?.toDouble(),
      createdAt: DateTime.parse(json['created_at']),
      updatedAt: DateTime.parse(json['updated_at']),
    );
  }
}
