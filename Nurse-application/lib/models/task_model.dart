class Task {
  final int taskId;
  final int shiftId;
  final String? details;
  final bool status;
  final String? comment;
  final String? taskCode;

  Task({
    required this.taskId,
    required this.shiftId,
    this.details,
    required this.status,
    this.comment,
    this.taskCode,
  });

  factory Task.fromJson(Map<String, dynamic> json) {
    return Task(
      taskId: json['task_id'] as int,
      shiftId: json['shift_id'] as int,
      details: json['details'] as String?,
      status: json['status'] as bool? ?? false,
      comment: json['comment'] as String?,
      taskCode: json['task_code'] as String?,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'task_id': taskId,
      'shift_id': shiftId,
      'details': details,
      'status': status,
      'comment': comment,
      'task_code': taskCode,
    };
  }
}
