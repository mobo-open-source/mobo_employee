import 'package:mobo_employees/features/manager/manager_attendance/service/manager_attendance_data_service.dart';

class ModelAttendanceGroupByData {
  final int length;
  final List<ManagerAttendanceMonthGroup> groups;

  ModelAttendanceGroupByData({required this.length, required this.groups});

  factory ModelAttendanceGroupByData.fromJson(dynamic json) {
    /// ---------------- CASE 1: read_group → List ----------------
    if (json is List) {
      final groups = json
          .whereType<Map>()
          .map(
            (e) => ManagerAttendanceMonthGroup.fromJson(
              Map<String, dynamic>.from(e),
            ),
          )
          .toList();

      return ModelAttendanceGroupByData(length: groups.length, groups: groups);
    }

    /// ---------------- CASE 2: web_read_group → Map ----------------
    if (json is Map) {
      final rawGroups = json['groups'];

      final groups = rawGroups is List
          ? rawGroups
                .whereType<Map>()
                .map(
                  (e) => ManagerAttendanceMonthGroup.fromJson(
                    Map<String, dynamic>.from(e),
                  ),
                )
                .toList()
          : <ManagerAttendanceMonthGroup>[];

      return ModelAttendanceGroupByData(
        length: json['length'] is int ? json['length'] : groups.length,
        groups: groups,
      );
    }

    /// ---------------- Fallback ----------------
    return ModelAttendanceGroupByData(length: 0, groups: []);
  }
}

class ManagerAttendanceMonthGroup implements AttendanceGroupNode {
  final DateTime? monthDate;
  final String monthLabel;

  final double workedHoursSum;
  final double overtimeHoursSum;
  final double validatedOvertimeHoursSum;
  final int count;
  final List<dynamic> extraDomain;

  ManagerAttendanceMonthGroup({
    required this.monthDate,
    required this.monthLabel,
    required this.workedHoursSum,
    required this.overtimeHoursSum,
    required this.validatedOvertimeHoursSum,
    required this.count,
    required this.extraDomain,
  });

  @override
  String get label => monthLabel;

  factory ManagerAttendanceMonthGroup.fromJson(Map<String, dynamic> json) {
    /// ---------- Month ----------
    DateTime? parsedDate;
    String label = '-';

    final monthValue = json['check_in:month'];

    /// web_read_group → [value, label]
    if (monthValue is List && monthValue.length == 2) {
      parsedDate = DateTime.tryParse(monthValue[0]?.toString() ?? '');
      label = monthValue[1]?.toString() ?? '-';
    }
    /// read_group → "January 2026"
    else if (monthValue is String) {
      label = monthValue;
    }

    /// ---------- Numeric helpers ----------
    double toDouble(dynamic v) => v is num ? v.toDouble() : 0.0;
    int toInt(dynamic v) => v is num ? v.toInt() : 0;

    /// ---------- Totals (handle BOTH keys) ----------
    final worked = json['worked_hours:sum'] ?? json['worked_hours'];
    final overtime = json['overtime_hours:sum'] ?? json['overtime_hours'];
    final validated =
        json['validated_overtime_hours:sum'] ??
        json['validated_overtime_hours'];

    /// ---------- Domain (handle BOTH keys) ----------
    final domain = json['__extra_domain'] ?? json['__domain'];
    final List<dynamic> safeDomain = domain is List
        ? List<dynamic>.from(domain)
        : [];

    return ManagerAttendanceMonthGroup(
      monthDate: parsedDate,
      monthLabel: label,
      workedHoursSum: toDouble(worked),
      overtimeHoursSum: toDouble(overtime),
      validatedOvertimeHoursSum: toDouble(validated),
      count: toInt(json['__count']),
      extraDomain: safeDomain,
    );
  }
}
