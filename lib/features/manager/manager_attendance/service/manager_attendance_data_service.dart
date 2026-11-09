import 'package:flutter/material.dart';
import 'package:mobo_employees/core/services/odoo_session_manager.dart';
import 'package:mobo_employees/features/employee/attendance/service/administrator_attendance_service.dart';
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
          // Odoo 20 removed the overtime fields from hr.attendance
          if (majorVersion < 20) 'overtime_hours',
          if (majorVersion >= 18 && majorVersion < 20)
            'validated_overtime_hours',
          if (majorVersion >= 18 && majorVersion < 20) 'overtime_status',
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

    final searchDomain = [
      ...?domain,
      if (search.isNotEmpty) ['employee_id', 'ilike', search],
    ];

    // Odoo 20 removed the legacy read_group signature and the overtime fields
    if (majorVersion >= 20) {
      final result = await odooClient({
        'model': 'hr.attendance',
        'method': 'web_read_group',
        'args': [],
        'kwargs': {
          'domain': searchDomain,
          'groupby': ['check_in:month'],
          'aggregates': ['__count', 'worked_hours:sum'],
          if (limit > 0) 'limit': limit,
          'offset': offset,
          'order': 'check_in:month desc',
        },
      });

      return ModelAttendanceGroupByData.fromJson(
        _withBaseDomain(result, domain),
      );
    }

    final result = await odooClient({
      'model': 'hr.attendance',
      'method': 'read_group',
      'args': [],
      'kwargs': {
        'domain': searchDomain,
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

    final searchDomain = [
      ...?domain,
      if (search.isNotEmpty) ['employee_id', 'ilike', search],
    ];

    // Odoo 20 removed the legacy read_group signature and the overtime fields
    if (majorVersion >= 20) {
      final result = await odooClient({
        'model': 'hr.attendance',
        'method': 'web_read_group',
        'args': [],
        'kwargs': {
          'domain': searchDomain,
          'groupby': ['employee_id'],
          'aggregates': ['__count', 'worked_hours:sum'],
          if (limit > 0) 'limit': limit,
          'offset': offset,
          'order': 'employee_id',
        },
      });

      return ModelAttendanceGroupByEmployeeData.fromJson(
        _withBaseDomain(result, domain),
      );
    }

    final result = await odooClient({
      'model': 'hr.attendance',
      'method': 'read_group',
      'args': [
        searchDomain,
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

  /// web_read_group only returns the group's own condition in `__extra_domain`,
  /// while legacy read_group's `__domain` also carried the base domain.
  /// Prepend the base domain so group drill-downs keep the active filters.
  static dynamic _withBaseDomain(dynamic result, List<dynamic>? baseDomain) {
    if (baseDomain == null || baseDomain.isEmpty) return result;
    if (result is! Map || result['groups'] is! List) return result;

    for (final group in result['groups']) {
      if (group is Map && group['__extra_domain'] is List) {
        group['__extra_domain'] = [...baseDomain, ...group['__extra_domain']];
      }
    }
    return result;
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

  /// Creates an `hr.attendance` for [employeeId], as Odoo's Attendances >
  /// New form does. [checkIn]/[checkOut] are local times; Odoo stores UTC.
  /// Leave [checkOut] null to record an employee who is still checked in.
  ///
  /// Odoo enforces the rest (check-out after check-in, no overlapping or
  /// second open attendance, officer access to that employee) and raises a
  /// message the caller should show as-is.
  static Future<int> createAttendance({
    required int employeeId,
    required DateTime checkIn,
    DateTime? checkOut,
  }) async {
    final result = await OdooSessionManager.callKwWithCompany({
      'model': 'hr.attendance',
      'method': 'create',
      'args': [
        {
          'employee_id': employeeId,
          'check_in': AdministratorAttendanceService.odooUtc(checkIn),
          'check_out': checkOut == null
              ? false
              : AdministratorAttendanceService.odooUtc(checkOut),
        },
      ],
      'kwargs': {},
    });
    return result as int;
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
