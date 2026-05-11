class ModelHrAttendanceAllLeaves {
  final int id;
  final String displayName;
  final DateTime dateFrom;
  final DateTime dateTo;
  final ModelAllLeaveType leaveType;
  final String state;
  final int color;
  final ModelAllLeaveFlags flags;
  final ModelAllRequestUnit requestUnit;

  ModelHrAttendanceAllLeaves({
    required this.id,
    required this.displayName,
    required this.dateFrom,
    required this.dateTo,
    required this.leaveType,
    required this.state,
    required this.color,
    required this.flags,
    required this.requestUnit,
  });

  factory ModelHrAttendanceAllLeaves.fromJson(Map<String, dynamic> json) {
    return ModelHrAttendanceAllLeaves(
      id: json['id'],
      displayName: json['display_name'] ?? '',
      dateFrom: DateTime.parse(json['date_from']),
      dateTo: DateTime.parse(json['date_to']),
      leaveType: ModelAllLeaveType.fromList(json['holiday_status_id']),
      state: json['state'] ?? "",
      color: json['color'] ?? 0,
      flags: ModelAllLeaveFlags(
        isHatched: json['is_hatched'] ?? false,
        isStriked: json['is_striked'] ?? false,
      ),
      requestUnit: ModelAllRequestUnit.fromJson(json),
    );
  }
}

class ModelAllLeaveType {
  final int id;
  final String name;

  ModelAllLeaveType({required this.id, required this.name});

  factory ModelAllLeaveType.fromList(List data) {
    return ModelAllLeaveType(id: data[0], name: data[1] ?? "");
  }
}

class ModelAllLeaveFlags {
  final bool isHatched;
  final bool isStriked;

  ModelAllLeaveFlags({required this.isHatched, required this.isStriked});

  factory ModelAllLeaveFlags.fromState(String state) {
    return ModelAllLeaveFlags(
      isHatched: state == 'confirm',
      isStriked: state == 'refuse',
    );
  }
}

class ModelAllRequestUnit {
  final bool halfDay;
  final bool hours;
  final String fromPeriod;
  final String toPeriod;

  ModelAllRequestUnit({
    required this.halfDay,
    required this.hours,
    required this.fromPeriod,
    required this.toPeriod,
  });

  factory ModelAllRequestUnit.fromJson(Map<String, dynamic> json) {
    return ModelAllRequestUnit(
      halfDay: json['request_unit_half'],
      hours: json['request_unit_hours'],
      fromPeriod: json['request_date_from_period'],
      toPeriod: json['request_date_to_period'] ?? "",
    );
  }
}
