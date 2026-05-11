class AttendanceResponseModel {
  final int length;
  final List<AttendanceRecord> records;
  final bool hasData;

  AttendanceResponseModel({
    required this.length,
    required this.records,
    required this.hasData,
  });

  factory AttendanceResponseModel.fromJson(Map<String, dynamic> json) {
    final List<dynamic> recordList = (json['records'] as List<dynamic>?) ?? [];

    return AttendanceResponseModel(
      length: json['length'] ?? recordList.length,
      records: recordList
          .map((e) => AttendanceRecord.fromJson(e as Map<String, dynamic>))
          .toList(),
      hasData: recordList.isNotEmpty,
    );
  }

  factory AttendanceResponseModel.empty() {
    return AttendanceResponseModel(length: 0, records: [], hasData: false);
  }
}

class AttendanceRecord {
  final int id;
  final DateTime? checkIn;
  final DateTime? checkOut;
  final double workedHours;
  final double validatedOvertimeHours;
  final dynamic overtimeStatus;

  AttendanceRecord({
    required this.id,
    required this.checkIn,
    required this.checkOut,
    required this.workedHours,
    required this.validatedOvertimeHours,
    required this.overtimeStatus,
  });

  factory AttendanceRecord.fromJson(Map<String, dynamic> json) {
    return AttendanceRecord(
      id: json['id'] ?? 0,
      checkIn: json['check_in'] != null
          ? DateTime.tryParse(json['check_in'].toString())
          : null,
      checkOut: json['check_out'] != null
          ? DateTime.tryParse(json['check_out'].toString())
          : null,
      workedHours: (json['worked_hours'] is num)
          ? (json['worked_hours'] as num).toDouble()
          : 0.0,
      validatedOvertimeHours: (json['validated_overtime_hours'] is num)
          ? (json['validated_overtime_hours'] as num).toDouble()
          : 0.0,
      overtimeStatus: json['overtime_status'] ?? false,
    );
  }
}
