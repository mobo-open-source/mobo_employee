import 'dart:convert';
import 'dart:typed_data';

class ModelManagerEmployeesResponse {
  final List<ModelFetchManagerEmployeeDetails> employees;
  final int totalCount;

  ModelManagerEmployeesResponse({
    required this.employees,
    required this.totalCount,
  });
}

class ModelFetchManagerEmployeeDetails {
  final int id;
  final Uint8List? avatarBytes;
  final String name;
  final String? allocationRemainingDisplay;
  final String? displayName;
  final bool active;
  final String? allocationDisplay;
  final bool? showLeaves;
  final String? attendanceState;
  final bool? isAbsent;
  final String? hrPresenceState;
  final bool? hasWorkEntries;
  final double? totalOvertime;
  final double? hoursLastMonth;
  final double? hoursLastMonthOvertime;
  final bool? displayExtraHours;
  final String? jobTitle;
  final String? departmentName;
  final DateTime? writeDate;
  final String? employeeType;
  final String? workPhone;
  final String? workEmail;
  final String? mobilePhone;
  final String? privateEmail;
  final String? privatePhone;
  final String? maritalStatus;
  final int? children;
  final String? legalName;
  final String? additionalNote;
  final String? workLocationName;
  final String? timezone;
  final String? companyName;
  final String? hrIconDisplay;
  final int? employeeCarsCount;
  final int? relatedPartnersCount;
  final int? resourceCalendarId;
  final String? resourceCalendarName;

  ModelFetchManagerEmployeeDetails({
    required this.id,
    required this.name,
    this.avatarBytes,
    required this.active,
    this.allocationRemainingDisplay,
    this.displayName,
    this.allocationDisplay,
    this.showLeaves,
    this.attendanceState,
    this.isAbsent,
    this.hrPresenceState,
    this.hasWorkEntries,
    this.totalOvertime,
    this.hoursLastMonth,
    this.hoursLastMonthOvertime,
    this.displayExtraHours,
    this.jobTitle,
    this.departmentName,
    this.employeeType,
    this.writeDate,
    this.workPhone,
    this.workEmail,
    this.mobilePhone,
    this.privateEmail,
    this.privatePhone,
    this.maritalStatus,
    this.children,
    this.legalName,
    this.additionalNote,
    this.workLocationName,
    this.timezone,
    this.companyName,
    this.hrIconDisplay,
    this.employeeCarsCount,
    this.relatedPartnersCount,
    this.resourceCalendarId,
    this.resourceCalendarName,
  });

  factory ModelFetchManagerEmployeeDetails.fromJson(Map<String, dynamic> json) {
    final calendar = json['resource_calendar_id'];

    int? resourceCalendarId;
    String? resourceCalendarName;
    Uint8List? avatarBytes;

    if (calendar is Map) {
      resourceCalendarId = _intOrNull(calendar['id']);
      resourceCalendarName = _stringOrNull(calendar['display_name']);
    } else if (calendar is List && calendar.isNotEmpty) {
      resourceCalendarId = _intOrNull(calendar[0]);
      resourceCalendarName = calendar.length > 1
          ? _stringOrNull(calendar[1])
          : null;
    } else {
      resourceCalendarId = _intOrNull(calendar);
    }

    final avatar = json['avatar_128'];
    if (avatar is String && avatar.isNotEmpty) {
      try {
        avatarBytes = base64Decode(avatar);
      } catch (_) {
        avatarBytes = null;
      }
    }

    return ModelFetchManagerEmployeeDetails(
      id: json['id'] ?? 0,
      avatarBytes: avatarBytes,
      name: _stringOrNull(json['name']) ?? '',
      displayName: _stringOrNull(json['display_name']),
      active: json['active'] == true,

      allocationRemainingDisplay: _stringOrNull(
        json['allocation_remaining_display'],
      ),
      allocationDisplay: _stringOrNull(json['allocation_display']),
      showLeaves: _boolOrNull(json['show_leaves']),
      attendanceState: _stringOrNull(json['attendance_state']),
      isAbsent: _boolOrNull(json['is_absent']),
      hrPresenceState: _stringOrNull(json['hr_presence_state']),
      hasWorkEntries: _boolOrNull(json['has_work_entries']),

      totalOvertime: _doubleOrNull(json['total_overtime']),
      hoursLastMonth: _doubleOrNull(json['hours_last_month']),
      hoursLastMonthOvertime: _doubleOrNull(json['hours_last_month_overtime']),
      displayExtraHours: _boolOrNull(json['display_extra_hours']),

      jobTitle: _displayName(json['job_id']),
      departmentName: _displayName(json['department_id']),

      writeDate: json['write_date'] != null && json['write_date'] != false
          ? DateTime.tryParse(json['write_date'].toString())
          : null,

      employeeType: _stringOrNull(json['employee_type']),
      workPhone: _stringOrNull(json['work_phone']),
      workEmail: _stringOrNull(json['work_email']),
      mobilePhone: _stringOrNull(json['mobile_phone']),
      privateEmail: _stringOrNull(json['private_email']),
      privatePhone: _stringOrNull(json['private_phone']),

      maritalStatus: _stringOrNull(json['marital']),
      children: _intOrNull(json['children']),
      legalName: _stringOrNull(json['legal_name']),
      additionalNote: _stringOrNull(json['additional_note']),

      workLocationName: _displayName(json['work_location_id']),
      timezone: _stringOrNull(json['tz']),
      companyName: _displayName(json['company_id']),
      hrIconDisplay: _stringOrNull(json['hr_icon_display']),

      employeeCarsCount: _intOrNull(json['employee_cars_count']),
      relatedPartnersCount: _intOrNull(json['related_partners_count']),

      resourceCalendarId: resourceCalendarId,
      resourceCalendarName: resourceCalendarName,
    );
  }
}

extension EmployeeSafeGetters on ModelFetchManagerEmployeeDetails {
  String get safeName => name.isNotEmpty ? name : '-';

  String get safeJobTitle => jobTitle?.isNotEmpty == true ? jobTitle! : '-';

  String get safeDepartment =>
      departmentName?.isNotEmpty == true ? departmentName! : '-';

  String get safePhone => workPhone?.isNotEmpty == true ? workPhone! : '-';

  String get safeEmail => workEmail?.isNotEmpty == true ? workEmail! : '-';

  String get safeLocation =>
      workLocationName?.isNotEmpty == true ? workLocationName! : '-';
}

String? _stringOrNull(dynamic v) {
  if (v == null || v == false) return null;
  return v.toString();
}

bool? _boolOrNull(dynamic v) {
  if (v == null || v == false) return null;
  if (v is bool) return v;
  return null;
}

int? _intOrNull(dynamic v) {
  if (v == null || v == false) return null;
  if (v is int) return v;
  if (v is num) return v.toInt();
  return null;
}

double? _doubleOrNull(dynamic v) {
  if (v == null || v == false) return null;
  if (v is num) return v.toDouble();
  return 0.00;
}

String? _displayName(dynamic v) {
  if (v == null || v == false) return null;
  if (v is Map && v['display_name'] != null) {
    return v['display_name'].toString();
  }
  if (v is List && v.length > 1) {
    return v[1]?.toString();
  }
  return null;
}
