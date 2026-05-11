import 'package:flutter/material.dart';
import 'package:mobo_employees/core/services/odoo_session_manager.dart';

class ManagerDashboardDataService {
  /// Fetch Total Employees count (manager Dashboard)
  static Future<int> fetchTotalEmployeeCount() async {
    try {
      final session = await OdooSessionManager.getCurrentSession();
      final employeeCount = await OdooSessionManager.callKwWithCompany({
        'model': 'hr.employee',
        'method': 'search_count',
        'args': [
          [
            ['company_id', 'in', session!.allowedCompanyIds],
          ],
        ],
        'kwargs': {},
      });
      return employeeCount is int ? employeeCount : 0;
    } catch (e) {
      return 0;
    }
  }

  /// Fetch Today Attendance count (manager Dashboard)
  static Future<int> fetchTodayAttendanceCount() async {
    final now = DateTime.now();
    final startOfDay = DateTime(now.year, now.month, now.day);
    final endOfDay = startOfDay.add(const Duration(days: 1));

    String odooFormat(DateTime d) =>
        "${d.toUtc().year.toString().padLeft(4, '0')}-"
        "${d.toUtc().month.toString().padLeft(2, '0')}-"
        "${d.toUtc().day.toString().padLeft(2, '0')} "
        "${d.toUtc().hour.toString().padLeft(2, '0')}:"
        "${d.toUtc().minute.toString().padLeft(2, '0')}:"
        "${d.toUtc().second.toString().padLeft(2, '0')}";

    final attendanceCount = await OdooSessionManager.callKwWithCompany({
      'model': 'hr.attendance',
      'method': 'search_count',
      'args': [
        [
          ['check_in', '>=', odooFormat(startOfDay)],
          ['check_in', '<', odooFormat(endOfDay)],
        ],
      ],
    });

    return attendanceCount is int ? attendanceCount : 0;
  }

  /// Fetch Today Leave Total count (manager Dashboard)
  static Future<int> fetchTodayLeavesTotalCount() async {
    final now = DateTime.now();
    final startOfDay = DateTime(now.year, now.month, now.day);
    final endOfDay = startOfDay.add(const Duration(days: 1));

    String odooFormat(DateTime d) =>
        "${d.toUtc().year.toString().padLeft(4, '0')}-"
        "${d.toUtc().month.toString().padLeft(2, '0')}-"
        "${d.toUtc().day.toString().padLeft(2, '0')} "
        "${d.toUtc().hour.toString().padLeft(2, '0')}:"
        "${d.toUtc().minute.toString().padLeft(2, '0')}:"
        "${d.toUtc().second.toString().padLeft(2, '0')}";

    final result = await OdooSessionManager.callKwWithCompany({
      'model': 'hr.leave',
      'method': 'search_count',
      'args': [
        [
          ['state', '=', 'validate'],
          ['date_from', '>=', odooFormat(startOfDay)],
          ['date_from', '<', odooFormat(endOfDay)],
        ],
      ],
    });
    return result is int ? result : 0;
  }

  /// Fetch Leave Request count (manager Dashboard)
  static Future<int> fetchLeaveRequestCount() async {
    final totalLeaveRequestCount = await OdooSessionManager.callKwWithCompany({
      'model': 'hr.leave',
      'method': 'search_count',
      'args': [
        [
          [
            'state',
            'in',
            ['validate1', 'confirm'],
          ],
        ],
      ],
    });
    return totalLeaveRequestCount is int ? totalLeaveRequestCount : 0;
  }

  /// Fetch Leave Request count for Today(manager Dashboard)
  static Future<int> fetchLeaveRequestCountForToday() async {
    final now = DateTime.now();
    final todayDate =
        "${now.year.toString().padLeft(4, '0')}-"
        "${now.month.toString().padLeft(2, '0')}-"
        "${now.day.toString().padLeft(2, '0')}";
    final totalLeaveRequestCountForToday =
        await OdooSessionManager.callKwWithCompany({
          'model': 'hr.leave',
          'method': 'search_count',
          'args': [
            [
              [
                'state',
                'in',
                ['confirm', 'validate1'],
              ],
              ['request_date_from', '=', todayDate],
            ],
          ],
        });
    return totalLeaveRequestCountForToday is int
        ? totalLeaveRequestCountForToday
        : 0;
  }

  /// Fetch late check's of Employees

  /// Fetch calendar start time for today

  /// Fetch calendar start hour for today

  /// Fetch today’s first check-in per administrator

  /// Fetch calendar start hour for today


  /// Fetch calendar start hour for today (first working hour_from)
  static Future<double?> fetchTodayStartHour(int calendarId) async {
    final int weekday = DateTime.now().weekday - 1;
    final result = await OdooSessionManager.callKwWithCompany({
      'model': 'resource.calendar.attendance',
      'method': 'search_read',
      'args': [
        [
          ['calendar_id', '=', calendarId],
          ['dayofweek', '=', weekday.toString()],
          ['duration_hours', '>', 0],
        ],
      ],
      'kwargs': {
        'fields': ['hour_from'],
        'order': 'hour_from asc',
        'limit': 1,
      },
    });

    if (result is List && result.isNotEmpty) {
      final hourFrom = result.first['hour_from'];
      if (hourFrom is num) {
        return hourFrom.toDouble();
      }
    }
    return null;
  }

  /// Fetch today's first check-in time of a user (administrator)
  static Future<DateTime?> fetchTodayFirstCheckIn(int employeeId) async {
    final now = DateTime.now();
    final startOfDay = DateTime(now.year, now.month, now.day);
    final endOfDay = startOfDay.add(const Duration(days: 1));

    String odooFormat(DateTime d) =>
        "${d.toUtc().year.toString().padLeft(4, '0')}-"
        "${d.toUtc().month.toString().padLeft(2, '0')}-"
        "${d.toUtc().day.toString().padLeft(2, '0')} "
        "${d.toUtc().hour.toString().padLeft(2, '0')}:"
        "${d.toUtc().minute.toString().padLeft(2, '0')}:"
        "${d.toUtc().second.toString().padLeft(2, '0')}";

    final result = await OdooSessionManager.callKwWithCompany({
      'model': 'hr.attendance',
      'method': 'search_read',
      'args': [
        [
          ['employee_id', '=', employeeId],
          ['check_in', '>=', odooFormat(startOfDay)],
          ['check_in', '<', odooFormat(endOfDay)],
        ],
      ],
      'kwargs': {
        'fields': ['check_in'],
        'order': 'check_in asc',
        'limit': 1,
      },
    });

    if (result is List && result.isNotEmpty) {
      final checkInStr = result.first['check_in'];
      if (checkInStr is String) {
        final checkInTime = DateTime.parse(checkInStr).toLocal();
        return checkInTime;
      }
    }
    return null;
  }

  /// Fetch Today Calendar Start Hours
  static Future<List<Map<String, dynamic>>>
  fetchTodayCalendarStartHours() async {
    final int weekday = DateTime.now().weekday - 1;

    final List<Map<String, dynamic>> result = [];

    /// Fetch all calendars (length = 3 in your log)
    final calendars = await OdooSessionManager.callKwWithCompany({
      'model': 'resource.calendar',
      'method': 'search_read',
      'args': [],
      'kwargs': {
        'fields': ['id', 'name'],
      },
    });

    if (calendars is! List) return result;

    /// Fetch first working slot for today per calendar
    for (final cal in calendars) {
      final int calendarId = cal['id'];
      final String calendarName = cal['name'];

      final attendance = await OdooSessionManager.callKwWithCompany({
        'model': 'resource.calendar.attendance',
        'method': 'search_read',
        'args': [
          [
            ['calendar_id', '=', calendarId],
            ['dayofweek', '=', weekday.toString()],
            ['duration_hours', '>', 0],
          ],
        ],
        'kwargs': {
          'fields': ['id', 'name', 'hour_from'],
          'order': 'hour_from asc',
          'limit': 1,
        },
      });

      if (attendance is List && attendance.isNotEmpty) {
        final a = attendance.first;

        result.add({
          'calendar_id': calendarId,
          'calendar_name': calendarName,
          'attendance_id': a['id'],
          'attendance_name': a['name'],
          'hour_from': (a['hour_from'] as num).toDouble(),
        });
      }
    }
    return result;
  }

  /// Fetch attendance with user id, check-in time, date & weekday
  static Future<List<Map<String, dynamic>>> fetchAttendanceWithDayInfo() async {
    final now = DateTime.now();
    final startOfDay = DateTime(now.year, now.month, now.day);
    final endOfDay = startOfDay.add(const Duration(days: 1));

    String odooFormat(DateTime d) =>
        "${d.toUtc().year.toString().padLeft(4, '0')}-"
        "${d.toUtc().month.toString().padLeft(2, '0')}-"
        "${d.toUtc().day.toString().padLeft(2, '0')} "
        "${d.toUtc().hour.toString().padLeft(2, '0')}:"
        "${d.toUtc().minute.toString().padLeft(2, '0')}:"
        "${d.toUtc().second.toString().padLeft(2, '0')}";

    final result = await OdooSessionManager.callKwWithCompany({
      'model': 'hr.attendance',
      'method': 'search_read',
      'args': [
        [
          ['check_in', '>=', odooFormat(startOfDay)],
          ['check_in', '<', odooFormat(endOfDay)],
        ],
      ],
      'kwargs': {
        'fields': ['employee_id', 'check_in', 'check_out'],
        'order': 'check_in asc', /// first check-in first
      },
    });

    final List<Map<String, dynamic>> formatted = [];

    if (result is! List) return formatted;

    for (final record in result) {
      final employee = record['employee_id'];
      if (employee is! List || employee.length < 2) continue;

      final DateTime checkInTime = _safeDate(record['check_in']);
      final DateTime? checkOutTime = record['check_out'] != null
          ? _safeDate(record['check_out'])
          : null;

      formatted.add({
        'employee_id': employee[0],
        'employee_name': employee[1],
        'check_in_dt': checkInTime,
        'check_out_dt': checkOutTime,
        'date': _formatDate(checkInTime),
        'day': _formatDay(checkInTime),
        'check_in_time': _formatTime(checkInTime),
      });
    }

    return formatted;
  }

  /// Fetch administrator id, name & resource calendar
  static Future<List<Map<String, dynamic>>> fetchEmployeesWithCalendar() async {
    final result = await OdooSessionManager.callKwWithCompany({
      'model': 'hr.employee',
      'method': 'search_read',
      'args': [],
      'kwargs': {
        'fields': ['id', 'name', 'resource_calendar_id'],
      },
    });

    final List<Map<String, dynamic>> employees = [];

    if (result is! List) return employees;

    for (final record in result) {
      final int id = record['id'];
      final String name = record['name'] ?? '';

      final calendar = record['resource_calendar_id'];

      int? calendarId;
      String? calendarName;

      /// ✅ Handle Map-style many2one
      if (calendar is Map) {
        calendarId = calendar['id'];
        calendarName = calendar['display_name'];
      }
      /// ✅ Handle List-style many2one (fallback safety)
      else if (calendar is List && calendar.length >= 2) {
        calendarId = calendar[0];
        calendarName = calendar[1];
      }

      employees.add({
        'employee_id': id,
        'employee_name': name,
        'calendar_id': calendarId,
        'calendar_name': calendarName,
      });
    }

    return employees;
  }

  /// ---------- Helpers ----------

  /// Format Time to local
  static DateTime _safeDate(dynamic v) {
    try {
      String? dateStr;
      if (v is String && v.isNotEmpty) {
        dateStr = v;
      } else if (v is List && v.isNotEmpty && v.first is String) {
        dateStr = v.first;
      }

      if (dateStr != null) {
        String cleaned = dateStr.split('.').first.replaceAll(' ', 'T');
        if (!cleaned.endsWith('Z') && !cleaned.contains('+')) {
          cleaned = '${cleaned}Z';
        }
        return DateTime.parse(cleaned).toLocal();
      }
    } catch (e) {}
    return DateTime.now();
  }

  static String _formatTime(DateTime dt) {
    return "${dt.hour.toString().padLeft(2, '0')}:"
        "${dt.minute.toString().padLeft(2, '0')}";
  }

  static String _formatDate(DateTime dt) {
    return "${dt.year}-${dt.month.toString().padLeft(2, '0')}-"
        "${dt.day.toString().padLeft(2, '0')}";
  }

  static String _formatDay(DateTime dt) {
    const days = [
      'Monday',
      'Tuesday',
      'Wednesday',
      'Thursday',
      'Friday',
      'Saturday',
      'Sunday',
    ];
    return days[dt.weekday - 1];
  }
}
