class AttendanceEmployeeModel {
  final int id;
  final String name;
  final DateTime? writeDate;
  final bool isAbsent;
  final String attendanceState;
  final double hoursLastMonth;
  final int? resourceCalendarId;
  final String? resourceCalendarName;

  AttendanceEmployeeModel({
    required this.id,
    required this.name,
    required this.isAbsent,
    required this.attendanceState,
    required this.hoursLastMonth,
    this.writeDate,
    this.resourceCalendarId,
    this.resourceCalendarName,
  });

  AttendanceEmployeeModel copyWith({
    int? id,
    String? name,
    DateTime? writeDate,
    bool? isAbsent,
    String? attendanceState,
    double? hoursLastMonth,
    int? resourceCalendarId,
    String? resourceCalendarName,
  }) {
    return AttendanceEmployeeModel(
      id: id ?? this.id,
      name: name ?? this.name,
      writeDate: writeDate ?? this.writeDate,
      isAbsent: isAbsent ?? this.isAbsent,
      attendanceState: attendanceState ?? this.attendanceState,
      hoursLastMonth: hoursLastMonth ?? this.hoursLastMonth,
      resourceCalendarId: resourceCalendarId ?? this.resourceCalendarId,
      resourceCalendarName: resourceCalendarName ?? this.resourceCalendarName,
    );
  }

  static bool _bool(dynamic v) => v == true;
  static String _string(dynamic v) =>
      (v == null || v == false) ? '' : v.toString();
  static double _double(dynamic v) => (v is num) ? v.toDouble() : 0.0;

  factory AttendanceEmployeeModel.fromJson(Map<String, dynamic> json) {
    int? calendarId;
    String? calendarName;

    final calendar = json['resource_calendar_id'];
    if (calendar is List && calendar.isNotEmpty) {
      calendarId = calendar[0];
      calendarName = calendar.length > 1 ? calendar[1] : null;
    }

    return AttendanceEmployeeModel(
      id: json['id'],
      name: _string(json['name']),
      isAbsent: _bool(json['is_absent']),
      attendanceState: _string(json['attendance_state']),
      hoursLastMonth: _double(json['hours_last_month']),
      writeDate: json['write_date'] != null
          ? DateTime.tryParse(json['write_date'].toString())
          : null,
      resourceCalendarId: calendarId,
      resourceCalendarName: calendarName,
    );
  }
}
