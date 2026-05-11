import 'package:mobo_employees/features/manager/manager_attendance/service/manager_attendance_data_service.dart';

class ModelAttendanceGroupByEmployeeData {
  final int length;
  final List<ManagerAttendanceEmployeeGroup> groups;

  ModelAttendanceGroupByEmployeeData({
    required this.length,
    required this.groups,
  });

  factory ModelAttendanceGroupByEmployeeData.fromJson(dynamic json) {
    /// ---------- CASE 1: web_read_group ----------
    if (json is Map) {
      final rawGroups = json['groups'];

      final groups = rawGroups is List
          ? rawGroups
                .whereType<Map>()
                .map(
                  (e) => ManagerAttendanceEmployeeGroup.fromJson(
                    Map<String, dynamic>.from(e),
                  ),
                )
                .toList()
          : <ManagerAttendanceEmployeeGroup>[];

      return ModelAttendanceGroupByEmployeeData(
        length: json['length'] is int ? json['length'] : groups.length,
        groups: groups,
      );
    }

    /// ---------- CASE 2: read_group ----------
    if (json is List) {
      final groups = json
          .whereType<Map>()
          .map(
            (e) => ManagerAttendanceEmployeeGroup.fromJson(
              Map<String, dynamic>.from(e),
            ),
          )
          .toList();

      return ModelAttendanceGroupByEmployeeData(
        length: groups.length,
        groups: groups,
      );
    }

    return ModelAttendanceGroupByEmployeeData(length: 0, groups: []);
  }
}

class ManagerAttendanceEmployeeGroup implements AttendanceGroupNode {
  final int employeeId;
  final String employeeName;

  final double workedHoursSum;
  final double overtimeHoursSum;
  final double validatedOvertimeHoursSum;
  final int count;
  final List<dynamic> extraDomain;

  ManagerAttendanceEmployeeGroup({
    required this.employeeId,
    required this.employeeName,
    required this.workedHoursSum,
    required this.overtimeHoursSum,
    required this.validatedOvertimeHoursSum,
    required this.count,
    required this.extraDomain,
  });

  @override
  String get label => employeeName;

  factory ManagerAttendanceEmployeeGroup.fromJson(Map<String, dynamic> json) {
    /// ---------- Employee ----------
    int id = 0;
    String name = '-';

    final emp = json['employee_id'];

    /// web_read_group → [id, name]
    if (emp is List && emp.length == 2) {
      id = emp[0] is int ? emp[0] : 0;
      name = emp[1]?.toString() ?? '-';
    }

    /// ---------- Numeric helpers ----------
    double toDouble(dynamic v) => v is num ? v.toDouble() : 0.0;
    int toInt(dynamic v) => v is num ? v.toInt() : 0;

    /// ---------- Totals ----------
    final worked = json['worked_hours:sum'] ?? json['worked_hours'];
    final overtime = json['overtime_hours:sum'] ?? json['overtime_hours'];
    final validated =
        json['validated_overtime_hours:sum'] ??
        json['validated_overtime_hours'];

    /// ---------- Domain ----------
    final domain = json['__extra_domain'] ?? json['__domain'];
    final List<dynamic> safeDomain = domain is List
        ? List<dynamic>.from(domain)
        : [];

    return ManagerAttendanceEmployeeGroup(
      employeeId: id,
      employeeName: name,
      workedHoursSum: toDouble(worked),
      overtimeHoursSum: toDouble(overtime),
      validatedOvertimeHoursSum: toDouble(validated),
      count: toInt(json['__count']),
      extraDomain: safeDomain,
    );
  }
}
