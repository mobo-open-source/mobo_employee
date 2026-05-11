class EmployeeModel {
  final int id;
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

  EmployeeModel({
    required this.id,
    required this.name,
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

  factory EmployeeModel.fromJson(Map<String, dynamic> json) {
    final calendar = json['resource_calendar_id'];
    int? resourceCalendarId;
    String? resourceCalendarName;

    if (calendar is Map<String, dynamic>) {
      resourceCalendarId = calendar['id'];
      resourceCalendarName = calendar['display_name'];
    } else if (calendar is List && calendar.isNotEmpty) {
      resourceCalendarId = calendar[0];
      resourceCalendarName = calendar.length > 1 ? calendar[1] : null;
    } else if (calendar is int) {
      resourceCalendarId = calendar;
    }

    return EmployeeModel(
      id: json['id'],
      name: json['name'] ?? '',
      displayName: json['display_name'],
      active: json['active'] ?? false,
      allocationRemainingDisplay: json['allocation_remaining_display']
          ?.toString(),
      allocationDisplay: json['allocation_display']?.toString(),
      showLeaves: json['show_leaves'],
      attendanceState: json['attendance_state'],
      isAbsent: json['is_absent'],
      hrPresenceState: json['hr_presence_state'],
      hasWorkEntries: json['has_work_entries'],
      totalOvertime: (json['total_overtime'] as num?)?.toDouble(),
      hoursLastMonth: (json['hours_last_month'] as num?)?.toDouble(),
      hoursLastMonthOvertime: (json['hours_last_month_overtime'] as num?)
          ?.toDouble(),
      displayExtraHours: json['display_extra_hours'],
      jobTitle: json['job_title'],
      departmentName: json['department_id'] is Map
          ? json['department_id']['display_name']
          : null,
      writeDate: json['write_date'] != null
          ? DateTime.tryParse(json['write_date'].toString())
          : null,
      employeeType: json['employee_type'],
      workPhone: json['work_phone'] is String ? json['work_phone'] : null,
      workEmail: json['work_email'] is String ? json['work_email'] : null,
      mobilePhone: json['mobile_phone'] is String ? json['mobile_phone'] : null,
      privateEmail: json['private_email'] is String
          ? json['private_email']
          : null,
      privatePhone: json['private_phone'] is String
          ? json['private_phone']
          : null,
      maritalStatus: json['marital'],
      children: json['children'],
      legalName: json['legal_name'],
      additionalNote: json['additional_note'],
      workLocationName: json['work_location_id'] is Map
          ? json['work_location_id']['display_name']
          : null,
      timezone: json['tz'],
      companyName: json['company_id'] is Map
          ? json['company_id']['display_name']
          : null,
      hrIconDisplay: json['hr_icon_display'],
      employeeCarsCount: json['employee_cars_count'],
      relatedPartnersCount: json['related_partners_count'],
      resourceCalendarId: resourceCalendarId,
      resourceCalendarName: resourceCalendarName,
    );
  }
}
