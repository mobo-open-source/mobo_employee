class ModelResourceCalendarLeave {
  final int id;
  final String name;
  final int? resourceId;
  final DateTime? dateFrom;
  final DateTime? dateTo;
  final int? companyId;
  final int? calendarId;
  final int? workEntryTypeId;

  ModelResourceCalendarLeave({
    required this.id,
    required this.name,
    this.resourceId,
    this.dateFrom,
    this.dateTo,
    this.companyId,
    this.calendarId,
    this.workEntryTypeId,
  });

  ///  Safely extract Many2one ID
  static int? _many2one(dynamic value) {
    if (value == false || value == null) return null;
    if (value is Map && value.containsKey('id')) {
      return value['id'] as int?;
    }
    return null;
  }

  /// Safely parse DateTime
  static DateTime? _parseDate(dynamic value) {
    if (value == null || value == false) return null;
    return DateTime.tryParse(value.toString());
  }

  factory ModelResourceCalendarLeave.fromJson(Map<String, dynamic> json) {
    return ModelResourceCalendarLeave(
      id: json['id'] ?? 0,
      name: json['name'] ?? '',
      resourceId: _many2one(json['resource_id']),
      dateFrom: _parseDate(json['date_from']),
      dateTo: _parseDate(json['date_to']),
      companyId: _many2one(json['company_id']),
      calendarId: _many2one(json['calendar_id']),
      workEntryTypeId: _many2one(json['work_entry_type_id']),
    );
  }
}
