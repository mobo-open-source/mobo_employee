import 'package:flutter/material.dart';
import 'package:mobo_employees/core/services/odoo_session_manager.dart';
import 'package:mobo_employees/features/manager/manager_attendance/model/model_fetch_manager_attendance_groupby_data.dart';
import 'package:mobo_employees/features/manager/manager_attendance/model/model_fetch_manger_attendance_employee_group_by.dart';
import 'package:mobo_employees/features/manager/manager_attendance/model/model_manager_attendance_data.dart';

abstract class AttendanceGroupNode {
  String get label;
  int get count;
  List<dynamic> get extraDomain;
}

class ManagerAttendanceDataService {

  ///fetch Manager Attendence data
  static Future<ModelManagerAttendanceData> fetchManagerAttendancesData({
    List<dynamic>? domain,
    int? limit,
    int? offset,
    String search = '',
  }) async {
    final odooClient = await OdooSessionManager.callKwWithCompany;
    final client = await OdooSessionManager.getClient();
    final String serverVersionString = client!.sessionId!.serverVersion;
    final int majorVersion = int.parse(serverVersionString.split('.').first);
    final result = await odooClient({
      'model': 'hr.attendance',
      'method': 'search_read',
      'args': [],
      'kwargs': {
        'domain': [
          ...?domain,
          if (search.isNotEmpty) ['employee_id', 'ilike', search],
        ],
        'fields': [
          'employee_id',
          'check_in',
          'check_out',
          'worked_hours',
          'overtime_hours',
          if (majorVersion >= 18) 'validated_overtime_hours',
          if (majorVersion >= 18) 'overtime_status',
          'in_mode',
          'out_mode',
          'in_latitude',
          'in_longitude',
          'out_latitude',
          'out_longitude',
          'create_uid',
          'write_uid',
          'write_date',
          'color',
        ],
        'limit': limit,
        'offset': offset,
        'order': 'check_in desc',
      },
    });
    final normalizedJson = {'length': result.length, 'records': result};
    return ModelManagerAttendanceData.fromJson(normalizedJson);
  }


  ///fetch manager Group by attendence Data from odooo
  static Future<ModelAttendanceGroupByData> fetchManagerGroupByAttendancesData({
    required int limit,
    required int offset,
    required String search,
    List<dynamic>? domain,
  }) async {
    final odooClient = await OdooSessionManager.callKwWithCompany;

    final client = await OdooSessionManager.getClient();
    final String serverVersionString = client!.sessionId!.serverVersion;
    final int majorVersion = int.parse(serverVersionString.split('.').first);

    final result = await odooClient({
      'model': 'hr.attendance',
      'method': 'read_group',
      'args': [],
      'kwargs': {
        'domain': [
          ...?domain,
          if (search.isNotEmpty) ['employee_id', 'ilike', search],
        ],
        'fields': [
          'worked_hours',
          'overtime_hours',
          if (majorVersion >= 18) 'validated_overtime_hours',
        ],
        'groupby': ['check_in:month'],
        'lazy': false,
        'limit': limit,
        'offset': offset,
        'orderby': 'check_in desc',
      },
    });

    return ModelAttendanceGroupByData.fromJson(result);
  }


  static Future<ModelAttendanceGroupByEmployeeData>

  fetchManagerAttendanceGroupByEmployee({
    required int limit,
    required int offset,
    String search = '',
    List<dynamic>? domain,
  }) async {
    final odooClient = await OdooSessionManager.callKwWithCompany;
    final client = await OdooSessionManager.getClient();

    final String serverVersionString = client!.sessionId!.serverVersion;
    final int majorVersion = int.parse(serverVersionString.split('.').first);

    final result = await odooClient({
      'model': 'hr.attendance',
      'method': 'read_group',
      'args': [
        [
          ...?domain,
          if (search.isNotEmpty) ['employee_id', 'ilike', search],
        ],
        [
          'worked_hours',
          'overtime_hours',
          if (majorVersion >= 18) 'validated_overtime_hours',
          'employee_id',
        ],
        ['employee_id'],
      ],
      'kwargs': {
        'limit': limit,
        'offset': offset,
        'lazy': false,
        'orderby': 'employee_id',
      },

    });

    return ModelAttendanceGroupByEmployeeData.fromJson(result);
  }



  static Future<String?> fetchEmployeeUserProfileImage(int userId) async {
    try {
      final odooClient = await OdooSessionManager.callKwWithCompany;

      final response = await odooClient({
        'model': 'hr.employee',
        'method': 'search_read',
        'args': [],
        'kwargs': {
          'domain': [
            ['id', '=', userId],
          ],
          'fields': ['image_1920'],
        },
      });

      if (response is List && response.isNotEmpty) {
        return response.first['image_1920'];
      }
      return null;
    } catch (e) {
      return null;
    }
  }

  static Future<int> fetchManagerAttendanceCount({
    List<dynamic>? domain,
    String search = '',
  }) async {
    final odooClient = await OdooSessionManager.callKwWithCompany;

    final result = await odooClient({
      'model': 'hr.attendance',
      'method': 'search_count',
      'args': [
        [
          ...?domain,
          if (search.isNotEmpty) ['employee_id', 'ilike', search],
        ],
      ],
    });

    return result as int;
  }
}
