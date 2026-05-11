class ModelHrWorkingSchedules {
  final int id;
  final String name;
  final String displayName;
  final String scheduleType;
  final double hoursPerDay;
  final double hoursPerWeek;
  final double fullTimeRequiredHours;
  final double workTimeRate;
  final String timezone;
  final String timezoneOffset;
  final bool flexibleHours;
  final bool twoWeeksCalendar;
  final bool durationBased;
  final bool active;
  final String twoWeeksExplanation;
  final int associatedLeavesCount;
  final int workResourcesCount;
  final int? companyId;
  final String? companyName;

  final List<CalendarAttendance> attendanceLines;

  ModelHrWorkingSchedules({
    required this.id,
    required this.name,
    required this.displayName,
    required this.scheduleType,
    required this.hoursPerDay,
    required this.hoursPerWeek,
    required this.fullTimeRequiredHours,
    required this.workTimeRate,
    required this.timezone,
    required this.timezoneOffset,
    required this.flexibleHours,
    required this.twoWeeksCalendar,
    required this.durationBased,
    required this.active,
    required this.twoWeeksExplanation,
    required this.associatedLeavesCount,
    required this.workResourcesCount,
    required this.companyId,
    required this.companyName,
    required this.attendanceLines,
  });

  factory ModelHrWorkingSchedules.fromJson(Map<String, dynamic> json) {
    /// company_id → false OR {id, display_name}
    final company = json['company_id'];
    int? companyId;
    String? companyName;

    if (company is Map<String, dynamic>) {
      companyId = company['id'];
      companyName = company['display_name'];
    } else if (company is int) {
      companyId = company;
    }

    /// attendance_ids → false OR list
    final List<CalendarAttendance> attendanceLines =
        (json['attendance_ids'] is List)
        ? (json['attendance_ids'] as List)
              .map(
                (e) =>
                    CalendarAttendance.fromJson(Map<String, dynamic>.from(e)),
              )
              .toList()
        : [];

    return ModelHrWorkingSchedules(
      id: json['id'] ?? 0,
      name: json['name'] ?? '',
      displayName: json['display_name'] ?? '',
      scheduleType: json['schedule_type'] ?? '',
      hoursPerDay: (json['hours_per_day'] ?? 0).toDouble(),
      hoursPerWeek: (json['hours_per_week'] ?? 0).toDouble(),
      fullTimeRequiredHours: (json['full_time_required_hours'] ?? 0).toDouble(),
      workTimeRate: (json['work_time_rate'] ?? 0).toDouble(),
      timezone: json['tz'] ?? '',
      timezoneOffset: json['tz_offset'] ?? '',
      flexibleHours: json['flexible_hours'] ?? false,
      twoWeeksCalendar: json['two_weeks_calendar'] ?? false,
      durationBased: json['duration_based'] ?? false,
      active: json['active'] ?? false,
      twoWeeksExplanation: json['two_weeks_explanation'] ?? '',
      associatedLeavesCount: json['associated_leaves_count'] ?? 0,
      workResourcesCount: json['work_resources_count'] ?? 0,
      companyId: companyId,
      companyName: companyName,
      attendanceLines: attendanceLines,
    );
  }
}

class CalendarAttendance {
  final int id;
  final String name;
  final String dayOfWeek;
  final String dayPeriod;
  final double durationHours;
  final double hourFrom;
  final double hourTo;
  final double durationDays;
  final bool displayType;
  final int sequence;

  CalendarAttendance({
    required this.id,
    required this.name,
    required this.dayOfWeek,
    required this.dayPeriod,
    required this.durationHours,
    required this.hourFrom,
    required this.hourTo,
    required this.durationDays,
    required this.displayType,
    required this.sequence,
  });

  factory CalendarAttendance.fromJson(Map<String, dynamic> json) {
    return CalendarAttendance(
      id: json['id'] ?? 0,
      name: json['name'] ?? '',
      dayOfWeek: json['dayofweek']?.toString() ?? '',
      dayPeriod: json['day_period'] ?? '',
      durationHours: (json['duration_hours'] ?? 0).toDouble(),
      hourFrom: (json['hour_from'] ?? 0).toDouble(),
      hourTo: (json['hour_to'] ?? 0).toDouble(),
      durationDays: (json['duration_days'] ?? 0).toDouble(),
      displayType: json['display_type'] ?? false,
      sequence: json['sequence'] ?? 0,
    );
  }
}
