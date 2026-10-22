import 'package:flutter/material.dart';
import 'package:mobo_employees/core/services/connectivity_service.dart';
import 'package:mobo_employees/core/services/odoo_session_manager.dart';
import 'package:mobo_employees/features/employee/attendance/service/administrator_attendance_service.dart';
import 'package:mobo_employees/features/employee/dashboard/model/model_hr_attendance.dart';
import 'package:mobo_employees/features/employee/dashboard/model/model_hr_attendance_checkin_checkout.dart';
import 'package:mobo_employees/features/employee/attendance/model/model_hr_employee.dart';
import 'package:mobo_employees/features/employee/dashboard/model/model_hr_leave_dashboard.dart';
import 'package:mobo_employees/features/employee/leave/service/leave_service.dart';

class AdministratorDashboardService {

  /// Fetch the most recently requested leave, so a request just submitted
  /// shows up (as pending) instead of staying behind a leave that merely
  /// starts later.
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
        'kwargs': {'limit': 1, 'order': 'create_date desc, id desc'},
      });

      final records = List<Map<String, dynamic>>.from(result);
      if (records.isEmpty) return null;

      return HrLeave.fromJson(records.first);
    } catch (e) {
      if (ConnectivityService.isConnectivityError(e)) rethrow;
      return null;
    }
  }


  /// fetching leave request Count from odoo — the user's own requests
  /// awaiting approval, identical to the Time Off page's "Pending" card.
  static Future<int> fetchLeaveRequestCount() async {
    try {
      return await LeaveService.fetchMyPendingRequestCount();
    } catch (e) {
      if (ConnectivityService.isConnectivityError(e)) rethrow;
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
      if (ConnectivityService.isConnectivityError(e)) rethrow;
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
      if (ConnectivityService.isConnectivityError(e)) rethrow;
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

  /// Next public holiday that hasn't ended yet: global time off (no
  /// resource) set on the employee's working schedule or on every schedule,
  /// as in Odoo's Working Schedules → Public Holidays. Null if none is
  /// planned.
  static Future<({String name, DateTime start, DateTime end})?>
  fetchNextPublicHoliday({int? employeeId}) async {
    int? calendarId;
    if (employeeId != null) {
      final employee = await OdooSessionManager.callKwWithCompany({
        'model': 'hr.employee.public',
        'method': 'read',
        'args': [
          [employeeId],
          ['resource_calendar_id'],
        ],
        'kwargs': {},
      });
      if (employee is List && employee.isNotEmpty) {
        final calendar = employee.first['resource_calendar_id'];
        if (calendar is List && calendar.isNotEmpty) calendarId = calendar[0];
        if (calendar is Map) calendarId = calendar['id'];
      }
    }

    final result = await OdooSessionManager.callKwWithCompany({
      'model': 'resource.calendar.leaves',
      'method': 'search_read',
      'args': [
        [
          ['resource_id', '=', false],
          [
            'date_to',
            '>=',
            AdministratorAttendanceService.odooUtc(DateTime.now()),
          ],
          if (calendarId != null) ...[
            '|',
            ['calendar_id', '=', false],
            ['calendar_id', '=', calendarId],
          ] else
            ['calendar_id', '=', false],
        ],
      ],
      'kwargs': {
        'fields': ['name', 'date_from', 'date_to'],
        'order': 'date_from asc',
        'limit': 1,
      },
    });

    if (result is! List || result.isEmpty) return null;
    final record = result.first;
    final from = record['date_from'];
    final to = record['date_to'];
    if (from is! String || to is! String) return null;
    return (
      name: record['name'] is String ? record['name'] as String : '',
      start: AdministratorAttendanceService.parseOdooUtc(from),
      end: AdministratorAttendanceService.parseOdooUtc(to),
    );
  }

  /// Check-out time (local) of the employee's most recent attendance, or
  /// null if they never checked out. `attendance_user_data` reports only
  /// the last check-in.
  static Future<DateTime?> fetchLastCheckOut(int employeeId) async {
    final result = await OdooSessionManager.callKwWithCompany({
      'model': 'hr.attendance',
      'method': 'search_read',
      'args': [
        [
          ['employee_id', '=', employeeId],
          ['check_out', '!=', false],
        ],
      ],
      'kwargs': {
        'fields': ['check_out'],
        'order': 'check_out desc',
        'limit': 1,
      },
    });
    if (result is List && result.isNotEmpty) {
      final raw = result.first['check_out'];
      if (raw is String) return AdministratorAttendanceService.parseOdooUtc(raw);
    }
    return null;
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
