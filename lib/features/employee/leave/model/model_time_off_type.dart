class ModelTimeOffType {
  final int id;
  final String displayName;
  final int? sequence;
  final String? requestUnit;
  final String? leaveValidationType;
  final bool requiresAllocation;
  final String? allocationValidationType;
  final bool employeeRequests;
  final int? color;

  /// Responsible Users
  final List<int> responsibleIds;
  final List<String> responsibleNames;

  /// Work Entry Type
  final int? workEntryTypeId;
  final String? workEntryTypeName;

  ModelTimeOffType({
    required this.id,
    required this.displayName,
    this.sequence,
    this.requestUnit,
    this.leaveValidationType,
    required this.requiresAllocation,
    this.allocationValidationType,
    required this.employeeRequests,
    this.color,
    required this.responsibleIds,
    required this.responsibleNames,
    this.workEntryTypeId,
    this.workEntryTypeName,
  });

  factory ModelTimeOffType.fromJson(Map<String, dynamic> json) {
    final responsibleList = json['responsible_ids'] as List? ?? [];
    final responsibleIds = responsibleList.map((e) => e['id'] as int).toList();
    final responsibleNames = responsibleList
        .map((e) => e['display_name'] as String)
        .toList();
    final workEntry = json['work_entry_type_id'];
    return ModelTimeOffType(
      id: json['id'],
      displayName: json['display_name'] ?? '',
      sequence: json['sequence'],
      requestUnit: json['request_unit'],
      leaveValidationType: json['leave_validation_type'],
      requiresAllocation: json['requires_allocation'] ?? false,
      allocationValidationType: json['allocation_validation_type'],
      employeeRequests: json['employee_requests'] ?? false,
      color: json['color'],
      responsibleIds: responsibleIds,
      responsibleNames: responsibleNames,
      workEntryTypeId: workEntry is Map ? workEntry['id'] : null,
      workEntryTypeName: workEntry is Map ? workEntry['display_name'] : null,
    );
  }
}
