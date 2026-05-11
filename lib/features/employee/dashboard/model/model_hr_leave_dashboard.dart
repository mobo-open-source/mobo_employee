class HrLeave {
  final int id;
  final int supportedAttachmentIdsCount;
  final String state;

  // many2one
  final int employeeId;
  final String employeeName;

  final String leaveTypeRequestUnit;
  final bool requestUnitHours;
  final bool requestUnitHalf;

  final DateTime? requestDateFrom;
  final DateTime? requestDateTo;

  final double requestHourFrom;
  final double requestHourTo;

  final bool canApprove;
  final bool canValidate;
  final bool canRefuse;

  final String requestDateFromPeriod;
  final String requestDateToPeriod;

  final bool holidayStatusRequiresAllocation;

  // many2one
  final int holidayStatusId;
  final String holidayStatusName;

  final String durationDisplay;
  final double virtualRemainingLeaves;
  final double maxLeaves;

  HrLeave({
    required this.id,
    required this.supportedAttachmentIdsCount,
    required this.state,
    required this.employeeId,
    required this.employeeName,
    required this.leaveTypeRequestUnit,
    required this.requestUnitHours,
    required this.requestUnitHalf,
    required this.requestDateFrom,
    required this.requestDateTo,
    required this.requestHourFrom,
    required this.requestHourTo,
    required this.canApprove,
    required this.canValidate,
    required this.canRefuse,
    required this.requestDateFromPeriod,
    required this.requestDateToPeriod,
    required this.holidayStatusRequiresAllocation,
    required this.holidayStatusId,
    required this.holidayStatusName,
    required this.durationDisplay,
    required this.virtualRemainingLeaves,
    required this.maxLeaves,
  });

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'state': state,
      'holidayStatusName': holidayStatusName,
      'requestDateFrom': requestDateFrom?.toIso8601String(),
      'requestDateTo': requestDateTo,
    };
  }

  factory HrLeave.fromJson(Map<String, dynamic> json) {
    final employee = json['employee_id'];
    int employeeId = 0;
    String employeeName = '';

    if (employee is List && employee.length >= 2) {
      employeeId = employee[0] ?? 0;
      employeeName = employee[1]?.toString() ?? '';
    }
    final holiday = json['holiday_status_id'];
    int holidayStatusId = 0;
    String holidayStatusName = '';

    if (holiday is List && holiday.length >= 2) {
      holidayStatusId = holiday[0] ?? 0;
      holidayStatusName = holiday[1]?.toString() ?? '';
    }

    return HrLeave(
      id: json['id'] ?? 0,
      supportedAttachmentIdsCount: json['supported_attachment_ids_count'] ?? 0,
      state: json['state'] ?? '',

      employeeId: employeeId,
      employeeName: employeeName,

      leaveTypeRequestUnit: json['leave_type_request_unit'] ?? '',
      requestUnitHours: json['request_unit_hours'] ?? false,
      requestUnitHalf: json['request_unit_half'] ?? false,

      requestDateFrom: json['request_date_from'] != null
          ? DateTime.tryParse(json['request_date_from'])
          : null,
      requestDateTo: json['request_date_to'] != null
          ? DateTime.tryParse(json['request_date_to'])
          : null,

      requestHourFrom: json['request_hour_from'] is num
          ? (json['request_hour_from'] as num).toDouble()
          : 0.0,

      requestHourTo: json['request_hour_to'] is num
          ? (json['request_hour_to'] as num).toDouble()
          : 0.0,

      canApprove: json['can_approve'] ?? false,
      canValidate: json['can_validate'] ?? false,
      canRefuse: json['can_refuse'] ?? false,

      requestDateFromPeriod: json['request_date_from_period'] ?? '',
      requestDateToPeriod: json['request_date_to_period'] ?? '',

      holidayStatusRequiresAllocation:
          json['holiday_status_requires_allocation'] ?? false,

      holidayStatusId: holidayStatusId,
      holidayStatusName: holidayStatusName,

      durationDisplay: json['duration_display'] ?? '',
      virtualRemainingLeaves:
          (json['virtual_remaining_leaves'] as num?)?.toDouble() ?? 0,
      maxLeaves: (json['max_leaves'] as num?)?.toDouble() ?? 0,
    );
  }
}
