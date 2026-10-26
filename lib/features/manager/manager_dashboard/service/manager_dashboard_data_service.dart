import 'package:flutter/foundation.dart';
import 'package:mobo_employees/core/services/connectivity_service.dart';
import 'package:mobo_employees/core/services/odoo_session_manager.dart';
import 'package:mobo_employees/features/employee/attendance/service/administrator_attendance_service.dart';

/// The manager dashboard's figures. Each card counts what Odoo's record
/// rules let this user read, like the tab it opens, so the number on the
/// card is the number of rows there.
class ManagerDashboardDataService {
  /// Forgets what was learned about the server (call on logout, since the
  /// next login may be a different Odoo version).
  static void reset() {
    _modelFields.clear();
  }

  /// Fetch Total Employees count (manager Dashboard): the employees of the
  /// allowed companies, like the Employees tab.
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

  /// Today's attendances, earliest check-in first. The one domain behind
  /// both "Todays attendance" and "Late Check-ins", and the one the
  /// Attendance tab applies for its Today filter, so the cards and the list
  /// always agree.
  static Future<dynamic> _fetchTodayAttendances({
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
        ],
      ],
      'kwargs': {'fields': fields, 'order': 'check_in asc'},
    });
  }

  /// Fetch Today Attendance count (manager Dashboard). Counts employees,
  /// not attendance records: someone who checked in twice counts once.
  static Future<int> fetchTodayAttendanceCount() async {
    try {
      final attendances = await _fetchTodayAttendances(
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
  static Future<int> fetchTodayLeavesTotalCount() async {
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
  static Future<int> fetchLeaveRequestCount() async {
    try {
      final count = await OdooSessionManager.callKwWithCompany({
        'model': 'hr.leave',
        'method': 'search_count',
        'args': [
          [
            ['state', 'in', ['validate1', 'confirm']],
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
  static Future<int> fetchLeaveRequestCountForToday() async {
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
  static Future<int> fetchLateCheckInCount() async {
    try {
      final attendances = await _fetchTodayAttendances(
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

      final calendarIds = calendarOf.values.toSet().toList();
      return countLateCheckIns(
        firstCheckIn: firstCheckIn,
        calendarOf: calendarOf,
        startHours: await _fetchTodayStartHours(calendarIds),
        flexibleCalendars: await _fetchFlexibleCalendarIds(calendarIds),
      );
    } catch (e) {
      if (ConnectivityService.isConnectivityError(e)) rethrow;

      /// A failed query is indistinguishable from "nobody is late" on the
      /// card, so at least leave a trace for whoever wonders about the 0.
      if (kDebugMode) debugPrint('fetchLateCheckInCount failed: $e');
      return 0;
    }
  }

  /// How many of the employees in [firstCheckIn] (their first check-in
  /// today, by employee id) checked in after their working day started.
  ///
  /// [calendarOf] gives each employee's schedule and [startHours] the hour
  /// each schedule starts at today. An employee whose schedule has no start
  /// today, or is in [flexibleCalendars], can't be late.
  @visibleForTesting
  static int countLateCheckIns({
    required Map<int, DateTime> firstCheckIn,
    required Map<int, int> calendarOf,
    required Map<int, double> startHours,
    Set<int> flexibleCalendars = const {},
  }) {
    var late = 0;
    firstCheckIn.forEach((employeeId, checkIn) {
      final calendarId = calendarOf[employeeId];
      if (flexibleCalendars.contains(calendarId)) return;
      final startHour = startHours[calendarId];
      if (startHour == null) return;
      final checkInMinutes = checkIn.hour * 60 + checkIn.minute;
      if (checkInMinutes > (startHour * 60).round()) late++;
    });
    return late;
  }

  /// Fields of `resource.calendar.attendance` on this server. Odoo 20
  /// dropped `week_type` and added `date` and `duration_based`, so the
  /// query below is built from what exists rather than from the version.
  static final Map<String, Set<String>> _modelFields = {};

  static Future<Set<String>> _loadCalendarLineFields() =>
      _loadFields('resource.calendar.attendance');

  /// The field names [model] has on this server, read once.
  static Future<Set<String>> _loadFields(String model) async {
    final cached = _modelFields[model];
    if (cached != null) return cached;
    final result = await OdooSessionManager.callKwWithCompany({
      'model': model,
      'method': 'fields_get',
      'args': [],
      'kwargs': {
        'attributes': ['type'],
      },
    });
    final fields = result is Map
        ? result.keys.map((key) => key.toString()).toSet()
        : <String>{};
    if (fields.isNotEmpty) _modelFields[model] = fields;
    return fields;
  }

  /// The schedules among [calendarIds] set to Flexible Hours.
  ///
  /// Odoo 18 and 19 flag them on `resource.calendar`, but keep the weekly
  /// lines the schedule had before, which say nothing about when a flexible
  /// employee has to start. Odoo 17 has no such schedule, and Odoo 20 models
  /// it as a schedule with no lines at all, so neither has the field.
  static Future<Set<int>> _fetchFlexibleCalendarIds(
    List<int> calendarIds,
  ) async {
    final fields = await _loadFields('resource.calendar');
    if (!fields.contains('flexible_hours')) return {};
    final calendars = await OdooSessionManager.callKwWithCompany({
      'model': 'resource.calendar',
      'method': 'search_read',
      'args': [
        [
          ['id', 'in', calendarIds],
          ['flexible_hours', '=', true],
        ],
      ],
      'kwargs': {
        'fields': ['id'],
      },
    });
    if (calendars is! List) return {};
    return calendars
        .whereType<Map>()
        .map((calendar) => calendar['id'])
        .whereType<int>()
        .toSet();
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
    final lines = await OdooSessionManager.callKwWithCompany({
      'model': 'resource.calendar.attendance',
      'method': 'search_read',
      'args': [
        startHoursDomain(calendarIds: calendarIds, today: today, fields: fields),
      ],
      'kwargs': {
        'fields': startHoursReadFields(fields),
        'order': 'hour_from asc',
      },
    });

    if (lines is! List) return {};
    return startHoursFromLines(
      lines.whereType<Map>().map((l) => Map<String, dynamic>.from(l)).toList(),
      today,
    );
  }

  /// The `resource.calendar.attendance` lines of [calendarIds] that can start
  /// the working day on [today], given the [fields] this server has.
  ///
  /// Nothing here filters on `duration_hours`: up to Odoo 19 it's a computed
  /// field that isn't stored, so a domain on it isn't a valid search. Odoo 17
  /// and 18 quietly ignore such a condition (which let the empty section rows
  /// of two-week schedules through), and Odoo 20's reworked domain engine
  /// rejects it. Lines with no hours are dropped by [startHoursFromLines]
  /// instead, the same on every version.
  ///
  /// Which shape to ask for follows the fields the server has, never a guess
  /// at its version: Odoo 19 already has `duration_based` but not the dated,
  /// recurring lines (`date`, `recurrency_*`), and filtering on a field that
  /// isn't there is an error that ends the whole query.
  @visibleForTesting
  static List<dynamic> startHoursDomain({
    required List<int> calendarIds,
    required DateTime today,
    required Set<String> fields,
  }) {
    final hasDatedLines =
        fields.contains('date') && fields.contains('recurrency_until');
    final todayDate = _formatOdooDate(today);
    return [
      ['calendar_id', 'in', calendarIds],

      if (hasDatedLines) ...[
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

        /// A line can be limited to a period (Odoo's `_attendance_intervals_batch`
        /// skips it outside it), so one that hasn't started or has ended
        /// mustn't move the start of today's day.
        if (fields.contains('date_from')) ...[
          '|',
          ['date_from', '=', false],
          ['date_from', '<=', todayDate],
        ],
        if (fields.contains('date_to')) ...[
          '|',
          ['date_to', '=', false],
          ['date_to', '>=', todayDate],
        ],
      ],
    ];
  }

  /// The fields of `resource.calendar.attendance` to read: the two every
  /// version has, plus whichever of the rest [fields] says this server has.
  /// Asking `search_read` for a field the model lacks is an error, so none is
  /// requested on the strength of the version alone.
  @visibleForTesting
  static List<String> startHoursReadFields(Set<String> fields) => [
    'calendar_id',
    'hour_from',
    for (final field in const [
      /// [startHoursFromLines] drops the lines that don't work; see
      /// [startHoursDomain].
      'duration_hours',
      'duration_based',
      'dayofweek',
      'date',
      'recurrency',
      'recurrency_type',
      'recurrency_interval',
      'recurrency_until',
      'recurrency_excluded_occurences',
    ])
      if (fields.contains(field)) field,
  ];

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

      /// A line with no hours isn't working time (see [startHoursDomain] for
      /// why this isn't asked of the server). A row that doesn't say is kept.
      final hours = line['duration_hours'];
      if (hours is num && hours <= 0) continue;

      if (line['duration_based'] == true) {
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
