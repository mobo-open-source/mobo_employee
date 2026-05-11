import 'package:flutter/material.dart';
import 'package:mobo_employees/core/services/odoo_session_manager.dart';
import 'package:mobo_employees/features/employee/dashboard/model/model_hr_attendance.dart';
import 'package:mobo_employees/features/employee/dashboard/model/model_hr_attendance_checkin_checkout.dart';
import 'package:mobo_employees/features/employee/attendance/model/model_hr_employee.dart';
import 'package:mobo_employees/features/employee/dashboard/model/model_hr_leave_dashboard.dart';

class AdministratorDashboardService {

  ///fetch latest leave
  static Future<HrLeave?> fetchLatestLeave({int? employeeId}) async {
    try {
      final domain = <List>[
        if (employeeId != null) ['employee_id', '=', employeeId],
        [
          'state',
          'in',
          ['confirm', 'validate1', 'validate'],
        ],
      ];

      final result = await OdooSessionManager.callKwWithCompany({
        'model': 'hr.leave',
        'method': 'search_read',
        'args': [domain],
        'kwargs': {'limit': 1, 'order': 'request_date_from desc'},
      });

      final records = List<Map<String, dynamic>>.from(result);
      if (records.isEmpty) return null;

      return HrLeave.fromJson(records.first);
    } catch (e) {
      return null;
    }
  }


  /// fetching leave request Count from odoo
  static Future<int> fetchLeaveRequestCount() async {
    try {
      final result = await OdooSessionManager.callKwWithCompany({
        'model': 'hr.leave',
        'method': 'search_count',
        'args': [
          [
            [
              'state',
              'in',
              ['confirm', 'validate1'],
            ],
          ],
        ],
        'kwargs': {},
      });

      return result is int ? result : 0;
    } catch (e) {
      return 0;
    }
  }


  ///fetch employee by  user Id from odoo
  static Future<EmployeeModel?> fetchEmployeeByUserId(int userId) async {
    try {
      final odooClient = await OdooSessionManager.callKwWithCompany;
      final response = await odooClient({
        'model': 'hr.employee',
        'method': 'search_read',
        'args': [],
        'kwargs': {
          'domain': [
            ['user_id', '=', userId],
          ],
          'fields': ['id', 'name', 'allocation_remaining_display'],
          'limit': 1,
        },
      });

      if (response is List && response.isNotEmpty) {
        return EmployeeModel.fromJson(response.first);
      }

      return null;
    } catch (e) {
      throw Exception("Failed to fetch administrator: $e");
    }
  }

  ///fetch the attendance of employee
  static Future<AttendanceResponseModel> fetchEmployeeAttendance(
    int employeeId,
  ) async {
    try {
      final odooClient = await OdooSessionManager.callKwWithCompany;
      final session = await OdooSessionManager.getCurrentSession();
      final version = session!.odooSession.serverVersion;
      final response = await odooClient({
        'model': 'hr.attendance',
        'method': 'search_read',
        'args': [],
        'kwargs': {
          'domain': [
            ['employee_id', '=', employeeId],
          ],
          'fields': [
            'id',
            'check_in',
            'check_out',
            'worked_hours',
            if (version.contains("18") || version.contains("19"))
              'validated_overtime_hours',
            if (version.contains("18") || version.contains("19"))
              'overtime_status',
          ],
          'order': 'check_in desc',
        },
      });

      if (response is List) {
        return AttendanceResponseModel.fromJson({
          "length": response.length,
          "records": response,
        });
      }

      return AttendanceResponseModel.empty();
    } catch (e) {
      return AttendanceResponseModel.empty();
    }
  }

  /// fetch all check in and check out
  static Future<List<ModelHrAttendanceCheckInCheckout>>
  fetchAllCheckInCheckOut({required int employeeId, int limit = 50}) async {
    final client = await OdooSessionManager.callKwWithCompany;

    final response = await client({
      'model': 'hr.attendance',
      'method': 'search_read',
      'args': [],
      'kwargs': {
        'domain': [
          ['employee_id', '=', employeeId],
        ],
        'fields': [
          'check_in',
          'check_out',
          'worked_hours',
          'validated_overtime_hours',
          'overtime_status',
        ],
        'order': 'check_in desc',
        'limit': limit,
      },
    });

    if (response == null || response['records'] == null) {
      return [];
    }

    final List records = response['records'];

    return records
        .map(
          (e) => ModelHrAttendanceCheckInCheckout.fromJson(
            Map<String, dynamic>.from(e),
          ),
        )
        .toList();
  }

  /// fetch attendance state from Odoo
  Future getAttendanceState() async {
    try {
      final response = await OdooSessionManager.safeCallRPC(
        "/hr_attendance/attendance_user_data",
        "call",
        {},
      );

      return response;
    } catch (e) {
      rethrow;
    }
  }


  ///checkIn
  static Future<bool> checkIn(int employeeId) async {
    try {
      final response = await OdooSessionManager.safeCallRPC(
        "/hr_attendance/systray_check_in_out",
        "call",
        {},
      );

      if (response['attendance_state'] == "checked_in") {
        return true;
      }

      return false;
    } catch (e) {
      rethrow;
    }
  }

  ///checkout method
  static Future<bool> checkOut(int employeeId) async {
    try {
      final response = await OdooSessionManager.safeCallRPC(
        "/hr_attendance/systray_check_in_out",
        "call",
        {},
      );
      if (response['attendance_state'] == "checked_out") {
        return true;
      }
      return false;
    } catch (e) {
      rethrow;
    }
  }
}
