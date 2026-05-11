import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:mobo_employees/core/services/odoo_session_manager.dart';
import 'package:mobo_employees/features/employee/attendance/model/model_hr_attendance_all_leaves.dart';
import 'package:mobo_employees/features/employee/attendance/model/model_hr_employee_attendance.dart';
import 'package:mobo_employees/features/employee/attendance/model/model_hr_employee_gettimeoffdashboard.dart';
import 'package:mobo_employees/features/employee/attendance/model/model_hr_working_schedules.dart';
import 'package:mobo_employees/features/employee/attendance/model/model_leave_unusual_days.dart';
import 'package:mobo_employees/features/employee/attendance/model/model_resource_calender_leave.dart';

/// Service class for managing attendance and leave-related data for administrators and employees.
///
/// This service provides methods to fetch attendance records, leave data, holidays,
/// and working schedules from the Odoo backend.
class AdministratorAttendanceService {
  /// Normalizes a [DateTime] by removing the time component.
  static DateTime _normalize(DateTime d) => DateTime(d.year, d.month, d.day);

  /// Fetches the set of dates on which an employee had check-in records during a specific month.
  ///
  /// Returns a [Set<DateTime>] containing the normalized dates of check-ins.
  static Future<Set<DateTime>> fetchMonthlyCheckInDates({
    required int employeeId,
    required DateTime month,
  }) async {
    try {
      final odooClient = await OdooSessionManager.callKwWithCompany;

      final DateTime from = DateTime(month.year, month.month, 1);
      final DateTime to = DateTime(
        month.year,
        month.month + 1,
        1,
      ).subtract(const Duration(seconds: 1));

      final session = await OdooSessionManager.getCurrentSession();
      final version = session!.odooSession.serverVersion;

      /// Handle version-specific logic for Odoo 19 and earlier (e.g., Odoo 18)
      if (version.contains("19")) {
        final response = await odooClient({
          'model': 'hr.attendance',
          'method': 'web_read_group',
          'args': [],
          'kwargs': {
            'domain': [
              ['employee_id', '=', employeeId],
              [
                'check_in',
                '>=',
                DateFormat('yyyy-MM-dd HH:mm:ss').format(from),
              ],
              ['check_in', '<=', DateFormat('yyyy-MM-dd HH:mm:ss').format(to)],
            ],
            'groupby': ['check_in:day'],
          },
        });
        final Set<DateTime> dates = {};
        if (response is Map && response['groups'] is List) {
          for (final group in response['groups']) {
            final raw = group['check_in:day']?[0];
            if (raw != null) {
              final dt = DateTime.parse(raw).toLocal();
              dates.add(_normalize(dt));
            }
          }
        }
        return dates;
      } else {
        final response = await odooClient({
          'model': 'hr.attendance',
          'method': 'search_read',
          'args': [],
          'kwargs': {
            'domain': [
              ['employee_id', '=', employeeId],
              [
                'check_in',
                '>=',
                DateFormat('yyyy-MM-dd HH:mm:ss').format(from),
              ],
              ['check_in', '<=', DateFormat('yyyy-MM-dd HH:mm:ss').format(to)],
            ],
            'fields': ['check_in'],
            'order': 'check_in asc',
          },
        });

        final Set<DateTime> dates = {};

        if (response is List) {
          for (final record in response) {
            final raw = record['check_in'];
            if (raw != null) {
              final dt = DateTime.parse(raw).toLocal();
              dates.add(_normalize(dt));
            }
          }
        }

        return dates;
      }
    } catch (e) {
      rethrow;
    }
  }

  /// Formats a [DateTime] into an Odoo-compatible string format.
  static String _odooDate(DateTime dt) {
    return DateFormat('yyyy-MM-dd HH:mm:ss').format(dt);
  }

  /// Calculates the total number of days an employee was present during a specific month.
  ///
  /// This counts unique check-in days.
  static Future<int> fetchMonthlyAttendanceDays({
    required int employeeId,
    required DateTime month,
  }) async {
    final odooClient = await OdooSessionManager.callKwWithCompany;

    final fromDate = DateTime(month.year, month.month, 1);
    final toDate = DateTime(month.year, month.month + 1, 1);

    final result = await odooClient({
      'model': 'hr.attendance',
      'method': 'read_group',
      'args': [
        [
          ['employee_id', '=', employeeId],
          ['check_in', '>=', _odooDate(fromDate)],
          ['check_in', '<', _odooDate(toDate)],
        ],
        [],
        ['check_in:day'],
      ],
      'kwargs': {},
    });

    if (result is List) {
      return result.length;
    }

    return 0;
  }

  /// Formats a [DateTime] to "YYYY-MM-DD 00:00:00" string.
  String formatOdooDateTime(DateTime d) {
    return "${d.year}-${d.month.toString().padLeft(2, '0')}-"
        "${d.day.toString().padLeft(2, '0')} 00:00:00";
  }

  /// Fetches "unusual" days (e.g., non-working days or holidays) for the current year.
  Future<ModelLeaveUnusualDays?> fetchUnusualDays() async {
    try {
      final now = DateTime.now();

      final dateFrom = formatOdooDateTime(DateTime(now.year, 1, 1));

      final dateTo = formatOdooDateTime(
        DateTime(now.year + 1, now.month, now.day),
      );

      final result = await OdooSessionManager.callKwWithCompany({
        'model': 'hr.leave',
        'method': 'get_unusual_days',
        'args': [dateFrom, dateTo],
        'kwargs': {},
      });

      if (result is! Map<String, dynamic>) {
        return null;
      }

      return ModelLeaveUnusualDays.fromJson(result);
    } catch (e) {
      return null;
    }
  }

  /// Fetches all validated leave records for a specific employee.
  static Future<List<ModelHrAttendanceAllLeaves>> fetchAllLeaves({
    int? employeeId,
  }) async {
    try {
      final domain = <List>[
        if (employeeId != null) ['employee_id', '=', employeeId],
        [
          'state',
          'in',
          ['validate'],
        ],
      ];

      final result = await OdooSessionManager.callKwWithCompany({
        'model': 'hr.leave',
        'method': 'search_read',
        'args': [],
        'kwargs': {'domain': domain},
      });

      final records = List<Map<String, dynamic>>.from(result);

      return records
          .map((e) => ModelHrAttendanceAllLeaves.fromJson(e))
          .toList();
    } catch (e) {
      return [];
    }
  }

  /// Fetches public holidays and other global calendar leaves for a specific month.
  static Future<List<ModelResourceCalendarLeave>> fetchHolidays({
    required DateTime month,
  }) async {
    final odooClient = await OdooSessionManager.callKwWithCompany;

    final monthStart = DateTime(month.year, month.month, 1);
    final monthEnd = DateTime(month.year, month.month + 1, 0, 23, 59, 59);

    final response = await odooClient({
      'model': 'resource.calendar.leaves',
      'method': 'search_read',
      'args': [],
      'kwargs': {
        'domain': [
          '&',
          ['date_from', '<=', monthEnd.toIso8601String()],
          ['date_to', '>=', monthStart.toIso8601String()],
        ],
        'fields': [
          'id',
          'name',
          'date_from',
          'date_to',
          'company_id',
          'calendar_id',
        ],
      },
    });

    if (response == null || response is! List) return [];

    return response
        .whereType<Map<String, dynamic>>()
        .map(ModelResourceCalendarLeave.fromJson)
        .toList();
  }

  /// Fetches public employee information and monthly worked hours by employee ID.
  static Future<AttendanceEmployeeModel?> fetchEmployeeByEmployeeId(
    int employeeId,
  ) async {
    try {
      final response = await OdooSessionManager.callKwWithCompany({
        'model': 'hr.employee.public',
        'method': 'search_read',
        'args': [],
        'kwargs': {
          'domain': [
            ['id', '=', employeeId],
          ],
        },
      });

      if (response is List && response.isNotEmpty) {
        final session = await OdooSessionManager.getCurrentSession();
        final version = session!.odooSession.serverVersion;
        if (version.contains("19")) {
          return AttendanceEmployeeModel.fromJson(response.first);
        } else {
          /// Fallback logic for calculating worked hours if server version is not 19
          final DateTime from = DateTime(
            DateTime.now().year,
            DateTime.now().month,
            1,
          );
          final DateTime to = DateTime(
            DateTime.now().year,
            DateTime.now().month + 1,
            1,
          ).subtract(const Duration(seconds: 1));
          final records = await OdooSessionManager.callKwWithCompany({
            'model': 'hr.attendance',
            'method': 'search_read',
            'args': [],
            'kwargs': {
              'domain': [
                ['employee_id', '=', employeeId],
                ['check_in', '>=', from.toIso8601String()],
                ['check_in', '<=', to.toIso8601String()],
              ],
              'fields': ['worked_hours'],
            },
          });

          double total = 0.0;
          if (records is List) {
            for (final r in records) {
              final h = r['worked_hours'];
              if (h is num) total += h.toDouble();
            }
          }

          final details = AttendanceEmployeeModel.fromJson(response.first);
          return details.copyWith(hoursLastMonth: total);
        }
      }
      return null;
    } catch (e) {
      throw Exception("Attendance administrator fetch failed: $e");
    }
  }

  /// Helper to format [DateTime] for Odoo queries.
  static String _oodooDate(DateTime dt) {
    return DateFormat('yyyy-MM-dd HH:mm:ss').format(dt);
  }

  /// Calculates the total number of leave days an employee took during a specific month.
  static Future<int> fetchMonthlyLeaveDays({
    required int employeeId,
    required DateTime month,
  }) async {
    final odooClient = await OdooSessionManager.callKwWithCompany;

    final fromDate = DateTime(month.year, month.month, 1);
    final toDate = DateTime(month.year, month.month + 1, 0, 23, 59, 59);

    final result = await odooClient({
      'model': 'hr.leave',
      'method': 'search_read',
      'args': [
        [
          ['employee_id', '=', employeeId],
          ['state', '=', 'validate'],
          ['date_from', '<=', _oodooDate(toDate)],
          ['date_to', '>=', _oodooDate(fromDate)],
        ],
      ],
      'kwargs': {
        'fields': ['date_from', 'date_to'],
      },
    });

    if (result is! List) return 0;

    int totalDays = 0;

    for (final leave in result) {
      final leaveStart = DateTime.parse(leave['date_from']);
      final leaveEnd = DateTime.parse(leave['date_to']);

      /// Calculate overlap with the specified month
      final start = leaveStart.isAfter(fromDate) ? leaveStart : fromDate;
      final end = leaveEnd.isBefore(toDate) ? leaveEnd : toDate;

      final days = end.difference(start).inDays + 1;
      if (days > 0) totalDays += days;
    }

    return totalDays;
  }

  /// Fetches details about a specific working calendar (resource schedule).
  static Future<ModelHrWorkingSchedules?> fetchWorkingCalendar({
    required int calendarId,
  }) async {
    final odooClient = await OdooSessionManager.callKwWithCompany;

    final response = await odooClient({
      'model': 'resource.calendar',
      'method': 'web_read',
      'args': [
        [calendarId],
      ],
      'kwargs': {
        'specification': {
          'id': {},
          'name': {},
          'display_name': {},
          'attendance_ids': {
            'fields': {
              'id': {},
              'dayofweek': {},
              'day_period': {},
              'hour_from': {},
              'hour_to': {},
              'duration_hours': {},
              'display_type': {},
              'sequence': {},
            },
          },
        },
      },
    });

    if (response is List && response.isNotEmpty) {
      return ModelHrWorkingSchedules.fromJson(
        Map<String, dynamic>.from(response.first),
      );
    }

    return null;
  }

  /// Fetches the time-off dashboard data for the current employee.
  static Future<TimeOffDashboardModel?>
  fetchEmployeeGetTimeOffDashboard() async {
    try {
      final response = await OdooSessionManager.callKwWithCompany({
        'model': 'hr.employee',
        'method': 'get_time_off_dashboard_data',
        'args': [],
        'kwargs': {},
      });

      if (response != null && response is Map<String, dynamic>) {
        return TimeOffDashboardModel.fromJson(response);
      }

      return null;
    } catch (e) {
      throw Exception("Failed to fetch dashboard: $e");
    }
  }

  /// Fetches the first check-in and last check-out for an employee on a specific day.
  Future getDailyAttendance(int employeeId, DateTime day) async {
    DateTime? firstCheckIn;
    DateTime? lastCheckOut;

    final todayStart = day;
    final start = DateTime(todayStart.year, todayStart.month, todayStart.day);
    final end = start.add(const Duration(days: 1));

    final result = await OdooSessionManager.callKwWithCompany({
      'model': 'hr.attendance',
      'method': 'search_read',
      'args': [],
      'kwargs': {
        'domain': [
          ['employee_id', '=', employeeId],
          ['check_in', '>=', start.toIso8601String()],
          ['check_in', '<', end.toIso8601String()],
        ],
        'fields': ['employee_id', 'check_in', 'check_out', 'worked_hours'],
      },
    });
    for (var record in result) {
      DateTime checkIn = DateTime.parse(record['check_in'] + 'Z').toLocal();
      if (firstCheckIn == null || checkIn.isBefore(firstCheckIn)) {
        firstCheckIn = checkIn;
      }
      if (record['check_out'] != false && record['check_out'] != null) {
        DateTime checkOut = DateTime.parse(record['check_out'] + 'Z').toLocal();
        if (lastCheckOut == null || checkOut.isAfter(lastCheckOut)) {
          lastCheckOut = checkOut;
        }
      }
    }
    return {"first_check_in": firstCheckIn, "last_check_out": lastCheckOut};
  }
}
