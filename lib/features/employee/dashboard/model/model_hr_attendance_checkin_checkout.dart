class ModelHrAttendanceCheckInCheckout {
  final int id;
  final DateTime checkIn;
  final DateTime? checkOut;
  final double workedHours;
  final double validatedOvertimeHours;
  final bool overtimeStatus;

  ModelHrAttendanceCheckInCheckout({
    required this.id,
    required this.checkIn,
    this.checkOut,
    required this.workedHours,
    required this.validatedOvertimeHours,
    required this.overtimeStatus,
  });

  factory ModelHrAttendanceCheckInCheckout.fromJson(Map<String, dynamic> json) {
    return ModelHrAttendanceCheckInCheckout(
      id: json['id'] as int,
      checkIn: DateTime.parse(json['check_in']).toLocal(),
      checkOut: json['check_out'] == false || json['check_out'] == null
          ? null
          : DateTime.parse(json['check_out']).toLocal(),
      workedHours: (json['worked_hours'] ?? 0).toDouble(),
      validatedOvertimeHours: (json['validated_overtime_hours'] ?? 0)
          .toDouble(),
      overtimeStatus: json['overtime_status'] ?? false,
    );
  }

  bool get isCheckedOut => checkOut != null;
}
