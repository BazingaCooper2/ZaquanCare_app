class DailyShift {
  final String shiftDate;
  final int empId;
  final String? shiftStartTime;
  final String? shiftEndTime;
  final int? dailyHrs;
  final int? monthlyHrs;
  final String shiftType;

  DailyShift({
    required this.shiftDate,
    required this.empId,
    this.shiftStartTime,
    this.shiftEndTime,
    this.dailyHrs,
    this.monthlyHrs,
    required this.shiftType,
  });

  factory DailyShift.fromJson(Map<String, dynamic> json) {
    return DailyShift(
      shiftDate: json['shift_date'],
      empId: json['emp_id'],
      shiftStartTime: json['shift_start_time'],
      shiftEndTime: json['shift_end_time'],
      dailyHrs: json['daily_hrs'],
      monthlyHrs: json['monthly_hrs'],
      shiftType: json['shift_type'],
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'shift_date': shiftDate,
      'emp_id': empId,
      'shift_start_time': shiftStartTime,
      'shift_end_time': shiftEndTime,
      'daily_hrs': dailyHrs,
      'monthly_hrs': monthlyHrs,
      'shift_type': shiftType,
    };
  }
}

