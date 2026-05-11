import 'package:flutter/material.dart';

class ModelManagerAttendanceData {
  final int attendanceLength;
  final List<AttendanceRecord> attendanceRecords;

  ModelManagerAttendanceData({
    required this.attendanceLength,
    required this.attendanceRecords,
  });

  ///  Unified parser (works with normalized search_read data)
  factory ModelManagerAttendanceData.fromJson(Map<String, dynamic> json) {
    final records = json['records'] as List? ?? [];

    return ModelManagerAttendanceData(
      attendanceLength: json['length'] ?? records.length,
      attendanceRecords: records
          .whereType<Map<String, dynamic>>()
          .map((e) => AttendanceRecord.fromJson(e))
          .toList(),
    );
  }
}

class AttendanceRecord {
  final int id;
  final HandleOdooData? employee;
  final DateTime? checkIn;
  final DateTime? checkOut;
  final double workedHours;
  final double overtimeHours;
  final double validatedOvertimeHours;
  final String? overtimeStatus;
  final String? inMode;
  final String? outMode;
  final double inLatitude;
  final double inLongitude;
  final double outLatitude;
  final double outLongitude;
  final HandleOdooData? createUser;
  final HandleOdooData? writeUser;
  final DateTime? writeDate;
  final int color;

  AttendanceRecord({
    required this.id,
    this.employee,
    this.checkIn,
    this.checkOut,
    required this.workedHours,
    required this.overtimeHours,
    required this.validatedOvertimeHours,
    this.overtimeStatus,
    this.inMode,
    this.outMode,
    required this.inLatitude,
    required this.inLongitude,
    required this.outLatitude,
    required this.outLongitude,
    this.createUser,
    this.writeUser,
    this.writeDate,
    required this.color,
  });

  factory AttendanceRecord.fromJson(Map<String, dynamic> json) {
    return AttendanceRecord(
      id: _parseInt(json['id']),

      employee: _parseRelation(json['employee_id']),
      createUser: _parseRelation(json['create_uid']),
      writeUser: _parseRelation(json['write_uid']),

      checkIn: _parseDate(json['check_in']),
      checkOut: _parseDate(json['check_out']),
      writeDate: _parseDate(json['write_date']),

      workedHours: _parseDouble(json['worked_hours']),
      overtimeHours: _parseDouble(json['overtime_hours']),
      validatedOvertimeHours: _parseDouble(json['validated_overtime_hours']),

      overtimeStatus: _parseString(json['overtime_status']),
      inMode: _parseString(json['in_mode']),
      outMode: _parseString(json['out_mode']),

      inLatitude: _parseDouble(json['in_latitude']),
      inLongitude: _parseDouble(json['in_longitude']),
      outLatitude: _parseDouble(json['out_latitude']),
      outLongitude: _parseDouble(json['out_longitude']),

      color: _parseInt(json['color']),
    );
  }

  /// ----------------- SAFE PARSERS -----------------

  static DateTime? _parseDate(dynamic v) {
    try {
      String? dateStr;

      /// Odoo sometimes sends String
      if (v is String && v.isNotEmpty) {
        dateStr = v;
      }
      /// Sometimes list (rare, but safe)
      else if (v is List && v.isNotEmpty && v.first is String) {
        dateStr = v.first;
      }

      if (dateStr == null) return null;

      /// Remove microseconds & normalize
      String cleaned = dateStr.split('.').first.replaceAll(' ', 'T');

      /// Force UTC if timezone missing
      if (!cleaned.endsWith('Z') && !cleaned.contains('+')) {
        cleaned = '${cleaned}Z';
      }

      /// Parse as UTC and convert to local
      return DateTime.parse(cleaned).toLocal();
    } catch (e) {
      return null;
    }
  }

  static int _parseInt(dynamic value) {
    if (value == null || value == false) return 0;
    if (value is int) return value;
    if (value is num) return value.toInt();
    return 0;
  }

  static double _parseDouble(dynamic value) {
    if (value == null || value == false) return 0.0;
    if (value is num) return value.toDouble();
    return 0.0;
  }

  static String? _parseString(dynamic value) {
    if (value == null || value == false) return null;
    return value.toString();
  }



  static HandleOdooData? _parseRelation(dynamic value) {
    if (value == null || value == false) return null;

    if (value is Map<String, dynamic>) {
      return HandleOdooData.fromJson(value);
    }

    if (value is List && value.length >= 2) {
      return HandleOdooData(
        id: _parseInt(value[0]),
        name: _parseString(value[1]) ?? '',
      );
    }

    return null;
  }
}

class HandleOdooData {
  final int id;
  final String name;

  HandleOdooData({required this.id, required this.name});

  factory HandleOdooData.fromJson(Map<String, dynamic> json) {
    return HandleOdooData(
      id: AttendanceRecord._parseInt(json['id']),
      name: AttendanceRecord._parseString(json['display_name']) ?? '',
    );
  }
}
