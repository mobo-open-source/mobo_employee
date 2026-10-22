import 'package:flutter/foundation.dart';
import 'package:mobo_employees/core/services/connectivity_service.dart';
import 'package:mobo_employees/core/services/odoo_session_manager.dart';
import 'package:mobo_employees/core/services/user_access_service.dart';
import 'package:mobo_employees/features/employee/attendance/service/administrator_attendance_service.dart';
import 'package:mobo_employees/features/manager/manager_approvals/services/manager_calendar_service.dart';

/// Whose records the manager dashboard counts. Each card follows the rule of
/// the tab it opens, so the number on the card is the number of rows there:
/// a manager sees their own direct reports, unless Odoo already shows them
/// everyone.
class ManagerDashboardScope {
  final int userId;

  /// Odoo gives this user every attendance (Attendance Administrator, or
  /// "Manage all attendances" on Odoo 20+): the attendance cards aren't
  /// narrowed to direct reports, exactly like the Attendance tab.
  final bool allAttendances;

  /// HR Officers/Managers approve company-wide, so the time off cards aren't
  /// narrowed either — like the Approvals tab (see
  /// [ManagerCalendarService.isHrManagerOrOfficer]).
  final bool allLeaves;

  const ManagerDashboardScope({
    required this.userId,
    required this.allAttendances,
    required this.allLeaves,
  });

  List<List<dynamic>> get _attendanceScope => allAttendances
      ? const []
      : [
          ['employee_id.parent_id.user_id', '=', userId],
        ];

  List<List<dynamic>> get _leaveScope => allLeaves
      ? const []
      : [
          ['employee_id.parent_id.user_id', '=', userId],
        ];
}

class ManagerDashboardDataService {
  /// Reads which records [userId]'s dashboard may count; see
  /// [ManagerDashboardScope].
  static Future<ManagerDashboardScope> resolveScope(int userId) async {
    final allAttendances = await UserAccessService.canSeeAllAttendances();
    final allLeaves = await ManagerCalendarService.isHrManagerOrOfficer(userId);
    return ManagerDashboardScope(
      userId: userId,
      allAttendances: allAttendances,
      allLeaves: allLeaves,
    );
  }

  /// Forgets what was learned about the server (call on logout, since the
  /// next login may be a different Odoo version).
  static void reset() {
    _calendarLineFields = null;
  }

  /// Fetch Total Employees count (manager Dashboard) — scoped to the
  /// manager's own direct reports, never company-wide.
  static Future<int> fetchTotalEmployeeCount({
    required int managerUserId,
  }) async {
    try {
      final session = await OdooSessionManager.getCurrentSession();
      final employeeCount = await OdooSessionManager.callKwWithCompany({
        'model': 'hr.employee',
        'method': 'search_count',
        'args': [
          [
            '&',
            ['company_id', 'in', session!.allowedCompanyIds],
            ['parent_id.user_id', '=', managerUserId],
          ],
        ],
        'kwargs': {},
      });
      return employeeCount is int ? employeeCount : 0;
    } catch (e) {
      if (ConnectivityService.isConnectivityError(e)) rethrow;
      return 0;
    }
  }

  /// Start and end of today (device time) as Odoo UTC strings.
  static ({String start, String end}) _todayUtc() {
    final now = DateTime.now();
    final startOfDay = DateTime(now.year, now.month, now.day);
    final endOfDay = startOfDay.add(const Duration(days: 1));
    return (
      start: AdministratorAttendanceService.odooUtc(startOfDay),
      end: AdministratorAttendanceService.odooUtc(endOfDay),
    );
  }

  /// Today's attendances in [scope], earliest check-in first. The one
  /// domain behind both "Todays attendance" and "Late Check-ins", and the
  /// one the Attendance tab applies for its Today filter, so the cards and
  /// the list always agree.
  static Future<dynamic> _fetchTodayAttendances(
    ManagerDashboardScope scope, {
    required List<String> fields,
  }) {
    final today = _todayUtc();
    return OdooSessionManager.callKwWithCompany({
      'model': 'hr.attendance',
      'method': 'search_read',
      'args': [
        [
          ['check_in', '>=', today.start],
          ['check_in', '<', today.end],
          ['employee_id.active', '=', true],
          ...scope._attendanceScope,
        ],
      ],
      'kwargs': {'fields': fields, 'order': 'check_in asc'},
    });
  }

  /// Fetch Today Attendance count (manager Dashboard). Counts employees,
  /// not attendance records: someone who checked in twice counts once.
  static Future<int> fetchTodayAttendanceCount({
    required ManagerDashboardScope scope,
  }) async {
    try {
      final attendances = await _fetchTodayAttendances(
        scope,
        fields: ['employee_id'],
      );
      return _distinctEmployeeCount(attendances);
    } catch (e) {
      if (ConnectivityService.isConnectivityError(e)) rethrow;
      return 0;
    }
  }

  /// Fetch count of employees on leave today (manager Dashboard).
  /// Counts employees with an approved leave spanning today (not just
  /// starting today); one with two half-day leaves counts once.
  static Future<int> fetchTodayLeavesTotalCount({
    required ManagerDashboardScope scope,
  }) async {
    try {
      final today = _todayUtc();
      final leaves = await OdooSessionManager.callKwWithCompany({
        'model': 'hr.leave',
        'method': 'search_read',
        'args': [
          [
            ['state', '=', 'validate'],
            ['date_from', '<', today.end],
            ['date_to', '>=', today.start],
            ...scope._leaveScope,
          ],
        ],
        'kwargs': {
          'fields': ['employee_id'],
        },
      });
      return _distinctEmployeeCount(leaves);
    } catch (e) {
      if (ConnectivityService.isConnectivityError(e)) rethrow;
      return 0;
    }
  }

  /// Fetch Leave Request count (manager Dashboard): the requests awaiting
  /// approval — Odoo's "To Approve" (first and second approval).
  static Future<int> fetchLeaveRequestCount({
    required ManagerDashboardScope scope,
  }) async {
    try {
      final count = await OdooSessionManager.callKwWithCompany({
        'model': 'hr.leave',
        'method': 'search_count',
        'args': [
          [
            ['state', 'in', ['validate1', 'confirm']],
            ...scope._leaveScope,
          ],
        ],
        'kwargs': {},
      });
      return count is int ? count : 0;
    } catch (e) {
      if (ConnectivityService.isConnectivityError(e)) rethrow;
      return 0;
    }
  }

  /// Fetch count of leave requests submitted today (manager Dashboard):
  /// by creation time, whatever the dates requested or the state they've
  /// since reached (a no-validation type is approved on the spot).
  static Future<int> fetchLeaveRequestCountForToday({
    required ManagerDashboardScope scope,
  }) async {
    try {
      final today = _todayUtc();
      final count = await OdooSessionManager.callKwWithCompany({
        'model': 'hr.leave',
        'method': 'search_count',
        'args': [
          [
            ['state', 'not in', ['draft', 'cancel']],
            ['create_date', '>=', today.start],
            ['create_date', '<', today.end],
            ...scope._leaveScope,
          ],
        ],
        'kwargs': {},
      });
      return count is int ? count : 0;
    } catch (e) {
      if (ConnectivityService.isConnectivityError(e)) rethrow;
      return 0;
    }
  }

  /// Fetch Late Check-ins (manager Dashboard): employees whose first
  /// check-in today is after the start of their working day.
  ///
  /// The start comes from the employee's working schedule, compared with the
  /// check-in on the device's clock (see [startHoursFromLines]). Employees
  /// whose schedule has no start time today — a day off or flexible hours —
  /// can't be late.
  static Future<int> fetchLateCheckInCount({
    required ManagerDashboardScope scope,
  }) async {
    try {
      final attendances = await _fetchTodayAttendances(
        scope,
        fields: ['employee_id', 'check_in'],
      );
      if (attendances is! List) return 0;

      /// Ascending by check-in, so the first one seen is the day's first.
      final firstCheckIn = <int, DateTime>{};
      for (final record in attendances) {
        final employeeId = _many2oneId(record['employee_id']);
        final raw = record['check_in'];
        if (employeeId == null || raw is! String) continue;
        firstCheckIn.putIfAbsent(
          employeeId,
          () => AdministratorAttendanceService.parseOdooUtc(raw),
        );
      }
      if (firstCheckIn.isEmpty) return 0;

      final employees = await OdooSessionManager.callKwWithCompany({
        'model': 'hr.employee',
        'method': 'search_read',
        'args': [
          [
            ['id', 'in', firstCheckIn.keys.toList()],
          ],
        ],
        'kwargs': {
          'fields': ['id', 'resource_calendar_id'],
        },
      });
      if (employees is! List) return 0;

      final calendarOf = <int, int>{};
      for (final employee in employees) {
        final employeeId = employee['id'];
        final calendarId = _many2oneId(employee['resource_calendar_id']);
        if (employeeId is int && calendarId != null) {
          calendarOf[employeeId] = calendarId;
        }
      }
      if (calendarOf.isEmpty) return 0;

      final startHours = await _fetchTodayStartHours(
        calendarOf.values.toSet().toList(),
      );

      var late = 0;
      firstCheckIn.forEach((employeeId, checkIn) {
        final startHour = startHours[calendarOf[employeeId]];
        if (startHour == null) return;
        final checkInMinutes = checkIn.hour * 60 + checkIn.minute;
        if (checkInMinutes > (startHour * 60).round()) late++;
      });
      return late;
    } catch (e) {
      if (ConnectivityService.isConnectivityError(e)) rethrow;
      return 0;
    }
  }

  /// Fields of `resource.calendar.attendance` on this server. Odoo 20
  /// dropped `week_type` and added `date` and `duration_based`, so the
  /// query below is built from what exists rather than from the version.
  static Set<String>? _calendarLineFields;

  static Future<Set<String>> _loadCalendarLineFields() async {
    final cached = _calendarLineFields;
    if (cached != null) return cached;
    final result = await OdooSessionManager.callKwWithCompany({
      'model': 'resource.calendar.attendance',
      'method': 'fields_get',
      'args': [],
      'kwargs': {
        'attributes': ['type'],
      },
    });
    final fields = result is Map
        ? result.keys.map((key) => key.toString()).toSet()
        : <String>{};
    if (fields.isNotEmpty) _calendarLineFields = fields;
    return fields;
  }

  /// Odoo's `get_week_type`: which week of a two-week schedule [day] is in.
  static int _weekType(DateTime day) {
    final daysSinceYearOne = DateTime.utc(
      day.year,
      day.month,
      day.day,
    ).difference(DateTime.utc(1, 1, 1)).inDays;
    return (daysSinceYearOne ~/ 7) % 2;
  }

  /// For each of [calendarIds] that works today, the hour its day starts at
  /// (e.g. 8.5 = 08:30), in one query.
  static Future<Map<int, double>> _fetchTodayStartHours(
    List<int> calendarIds,
  ) async {
    final today = DateTime.now();
    final fields = await _loadCalendarLineFields();
    final isOdoo20 = fields.contains('duration_based');
    final todayDate = _formatOdooDate(today);
    final lines = await OdooSessionManager.callKwWithCompany({
      'model': 'resource.calendar.attendance',
      'method': 'search_read',
      'args': [
        [
          ['calendar_id', 'in', calendarIds],
          ['duration_hours', '>', 0],

          if (isOdoo20) ...[
            /// Fixed schedules repeat on a weekday; variable ones have dated
            /// lines, some recurring, which [startHoursFromLines] matches to
            /// today.
            '|',
            '&',
            ['date', '=', false],
            ['dayofweek', '=', '${today.weekday - 1}'],
            '&',
            ['date', '<=', todayDate],
            ['recurrency_until', '>=', todayDate],
          ] else ...[
            ['dayofweek', '=', '${today.weekday - 1}'],

            /// Two-week schedules (up to Odoo 19): only this week's lines.
            if (fields.contains('week_type'))
              ['week_type', 'in', [false, '${_weekType(today)}']],

            /// The lunch break isn't the start of the day.
            if (fields.contains('day_period')) ['day_period', '!=', 'lunch'],
          ],
        ],
      ],
      'kwargs': {
        'fields': [
          'calendar_id',
          'hour_from',
          if (isOdoo20) ...[
            'duration_hours',
            'duration_based',
            'dayofweek',
            'date',
            'recurrency',
            'recurrency_type',
            'recurrency_interval',
            'recurrency_until',
            'recurrency_excluded_occurences',
          ],
        ],
        'order': 'hour_from asc',
      },
    });

    if (lines is! List) return {};
    return startHoursFromLines(
      lines.whereType<Map>().map((l) => Map<String, dynamic>.from(l)).toList(),
      today,
    );
  }

  /// The hour each calendar's working day starts at on [day], from the
  /// `resource.calendar.attendance` [lines] read for it (e.g. 8.5 = 08:30).
  ///
  /// A calendar with time-based lines starts at the earliest `hour_from`. One
  /// with duration-based lines — Odoo 20's default schedules, which only say
  /// "8 hours a day" and store `hour_from` as 0 — has no start of its own, so
  /// it takes the one Odoo's resource module gives such a day when it lays it
  /// out on the clock (`_attendance_intervals_batch`): centred on noon, i.e.
  /// `12 - hours / 2`. A calendar with no line on [day] is left out.
  @visibleForTesting
  static Map<int, double> startHoursFromLines(
    List<Map<String, dynamic>> lines,
    DateTime day,
  ) {
    final timeBasedStart = <int, double>{};
    final durationHours = <int, double>{};
    for (final line in lines) {
      final calendarId = _many2oneId(line['calendar_id']);
      if (calendarId == null || !_occursOn(line, day)) continue;

      if (line['duration_based'] == true) {
        final hours = line['duration_hours'];
        if (hours is num) {
          durationHours[calendarId] =
              (durationHours[calendarId] ?? 0) + hours.toDouble();
        }
        continue;
      }

      final hourFrom = line['hour_from'];
      if (hourFrom is! num) continue;
      final current = timeBasedStart[calendarId];
      if (current == null || hourFrom < current) {
        timeBasedStart[calendarId] = hourFrom.toDouble();
      }
    }

    final startHours = <int, double>{...timeBasedStart};
    durationHours.forEach((calendarId, hours) {
      startHours.putIfAbsent(calendarId, () => 12 - hours / 2);
    });
    return startHours;
  }

  /// Odoo's `resource.calendar.attendance._filter_by_date`: whether [line]
  /// applies on [day]. A line without a date repeats on its weekday; a dated
  /// one applies on that date, or on the dates its recurrence rule yields.
  static bool _occursOn(Map<String, dynamic> line, DateTime day) {
    final rawDate = line['date'];
    if (rawDate is! String) {
      final weekday = line['dayofweek'];
      return weekday == null || weekday == '${day.weekday - 1}';
    }

    final start = DateTime.tryParse(rawDate);
    if (start == null) return false;
    final today = DateTime.utc(day.year, day.month, day.day);
    final daysSince = today
        .difference(DateTime.utc(start.year, start.month, start.day))
        .inDays;
    if (daysSince < 0) return false;
    if (line['recurrency'] != true) return daysSince == 0;

    final until = line['recurrency_until'];
    if (until is String) {
      final untilDate = DateTime.tryParse(until);
      if (untilDate != null &&
          today.isAfter(
            DateTime.utc(untilDate.year, untilDate.month, untilDate.day),
          )) {
        return false;
      }
    }
    final excluded = line['recurrency_excluded_occurences'];
    if (excluded is List && excluded.contains(_formatOdooDate(day))) {
      return false;
    }

    final interval = line['recurrency_interval'];
    if (interval is! int || interval < 1) return false;
    return line['recurrency_type'] == 'days'
        ? daysSince % interval == 0
        : daysSince % 7 == 0 && (daysSince ~/ 7) % interval == 0;
  }

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

  /// ---------- Helpers ----------

  static String _formatOdooDate(DateTime d) =>
      "${d.year.toString().padLeft(4, '0')}-"
      "${d.month.toString().padLeft(2, '0')}-"
      "${d.day.toString().padLeft(2, '0')}";

  /// The id of a many2one read as `[id, name]` (search_read) or as
  /// `{id, display_name}` (web_read); null when empty.
  static int? _many2oneId(dynamic value) {
    if (value is List && value.isNotEmpty && value.first is int) {
      return value.first as int;
    }
    if (value is Map && value['id'] is int) return value['id'] as int;
    return null;
  }

  /// Number of different employees in records read with `employee_id`.
  static int _distinctEmployeeCount(dynamic records) {
    if (records is! List) return 0;
    final ids = <int>{};
    for (final record in records) {
      final id = _many2oneId(record['employee_id']);
      if (id != null) ids.add(id);
    }
    return ids.length;
  }
}
