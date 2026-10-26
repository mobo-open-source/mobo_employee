import 'package:flutter_test/flutter_test.dart';
import 'package:mobo_employees/features/manager/manager_dashboard/service/manager_dashboard_data_service.dart';

/// A `resource.calendar.attendance` row as Odoo 20 returns it to
/// `search_read` (the lines below are copied from a real Odoo 20 database).
Map<String, dynamic> _line({
  required int calendarId,
  required double hourFrom,
  required double durationHours,
  required bool durationBased,
  String dayofweek = '0',
  dynamic date = false,
  bool recurrency = false,
  String recurrencyType = 'weeks',
  int recurrencyInterval = 1,
  dynamic recurrencyUntil = false,
  dynamic excluded = false,
}) => {
  'calendar_id': [calendarId, 'calendar $calendarId'],
  'hour_from': hourFrom,
  'duration_hours': durationHours,
  'duration_based': durationBased,
  'dayofweek': dayofweek,
  'date': date,
  'recurrency': recurrency,
  'recurrency_type': recurrencyType,
  'recurrency_interval': recurrencyInterval,
  'recurrency_until': recurrencyUntil,
  'recurrency_excluded_occurences': excluded,
};

void main() {
  /// Monday.
  final monday = DateTime(2026, 10, 19);

  group('ManagerDashboardDataService.startHoursFromLines', () {
    test('a time-based schedule starts at its earliest hour_from', () {
      final hours = ManagerDashboardDataService.startHoursFromLines([
        _line(calendarId: 6, hourFrom: 13, durationHours: 4, durationBased: false),
        _line(calendarId: 6, hourFrom: 8.5, durationHours: 4, durationBased: false),
      ], monday);

      expect(hours, {6: 8.5});
    });

    test(
      'Odoo 20 default schedules are duration-based: the day is centred on '
      'noon, as Odoo lays it out',
      () {
        final hours = ManagerDashboardDataService.startHoursFromLines([
          _line(calendarId: 1, hourFrom: 0, durationHours: 8, durationBased: true),
          _line(calendarId: 2, hourFrom: 0, durationHours: 7, durationBased: true),
          _line(calendarId: 4, hourFrom: 0, durationHours: 4, durationBased: true),
        ], monday);

        expect(hours, {1: 8.0, 2: 8.5, 4: 10.0});
      },
    );

    test('several duration-based lines on one day add up', () {
      final hours = ManagerDashboardDataService.startHoursFromLines([
        _line(calendarId: 1, hourFrom: 0, durationHours: 4, durationBased: true),
        _line(calendarId: 1, hourFrom: 0, durationHours: 4, durationBased: true),
      ], monday);

      expect(hours, {1: 8.0});
    });

    test('a calendar with no line on that weekday is left out', () {
      final hours = ManagerDashboardDataService.startHoursFromLines([
        _line(
          calendarId: 1,
          hourFrom: 0,
          durationHours: 8,
          durationBased: true,
          dayofweek: '5',
        ),
      ], monday);

      expect(hours, isEmpty);
    });

    test('Odoo 18/19 lines carry only calendar_id and hour_from', () {
      final hours = ManagerDashboardDataService.startHoursFromLines([
        {
          'calendar_id': [3, '40 hours'],
          'hour_from': 9.0,
        },
      ], monday);

      expect(hours, {3: 9.0});
    });

    test('lines with no hours are not working time, on any version', () {
      /// Before Odoo 20 the server isn't asked for this, so it's done here:
      /// an empty line mustn't pull the start of the day earlier.
      final hours = ManagerDashboardDataService.startHoursFromLines([
        {
          'calendar_id': [3, '40 hours'],
          'hour_from': 6.0,
          'duration_hours': 0.0,
        },
        {
          'calendar_id': [3, '40 hours'],
          'hour_from': 9.0,
          'duration_hours': 4.0,
        },
      ], monday);

      expect(hours, {3: 9.0});
    });

    group('variable schedules (dated lines)', () {
      test('a one-off line applies on its date only', () {
        final line = _line(
          calendarId: 7,
          hourFrom: 10,
          durationHours: 6,
          durationBased: false,
          date: '2026-10-19',
        );

        expect(
          ManagerDashboardDataService.startHoursFromLines([line], monday),
          {7: 10.0},
        );
        expect(
          ManagerDashboardDataService.startHoursFromLines([
            line,
          ], DateTime(2026, 10, 20)),
          isEmpty,
        );
      });

      test('a weekly recurrence follows its interval', () {
        final everyOtherWeek = _line(
          calendarId: 7,
          hourFrom: 7,
          durationHours: 8,
          durationBased: false,
          date: '2026-10-05',
          recurrency: true,
          recurrencyInterval: 2,
          recurrencyUntil: '9999-12-31',
        );

        expect(
          ManagerDashboardDataService.startHoursFromLines([
            everyOtherWeek,
          ], monday),
          {7: 7.0},
        );
        expect(
          ManagerDashboardDataService.startHoursFromLines([
            everyOtherWeek,
          ], DateTime(2026, 10, 12)),
          isEmpty,
        );
      });

      test('a daily recurrence, an end date and excluded days are honoured', () {
        final daily = _line(
          calendarId: 7,
          hourFrom: 9,
          durationHours: 8,
          durationBased: false,
          date: '2026-10-17',
          recurrency: true,
          recurrencyType: 'days',
          recurrencyInterval: 1,
          recurrencyUntil: '2026-10-20',
          excluded: ['2026-10-20'],
        );

        expect(
          ManagerDashboardDataService.startHoursFromLines([daily], monday),
          {7: 9.0},
        );
        expect(
          ManagerDashboardDataService.startHoursFromLines([
            daily,
          ], DateTime(2026, 10, 20)),
          isEmpty,
          reason: 'excluded occurrence',
        );
        expect(
          ManagerDashboardDataService.startHoursFromLines([
            daily,
          ], DateTime(2026, 10, 21)),
          isEmpty,
          reason: 'past the recurrence end date',
        );
      });
    });
  });

  group('ManagerDashboardDataService.startHoursDomain', () {
    /// The fields Odoo 17-19 have on `resource.calendar.attendance`.
    const classicFields = {
      'dayofweek',
      'hour_from',
      'week_type',
      'day_period',
      'date_from',
      'date_to',
    };

    /// What Odoo 20 has instead (no `week_type`; dated, recurring lines).
    const odoo20Fields = {
      'dayofweek',
      'hour_from',
      'day_period',
      'duration_hours',
      'duration_based',
      'date',
      'recurrency_until',
    };

    /// The field names the domain filters on.
    Set<String> filteredFields(List<dynamic> domain) =>
        domain.whereType<List>().map((leaf) => leaf.first as String).toSet();

    test('never filters on duration_hours, which is not stored before Odoo 20', () {
      /// Odoo 17/18 ignore a condition on it (so zero-hour rows slipped
      /// through) and Odoo 20 rejects it; the zero-hour rule lives in
      /// startHoursFromLines instead.
      for (final fields in [classicFields, odoo20Fields]) {
        final domain = ManagerDashboardDataService.startHoursDomain(
          calendarIds: [1, 2],
          today: monday,
          fields: fields,
        );
        expect(filteredFields(domain), isNot(contains('duration_hours')));
      }
    });

    test('Odoo 17-19: today\'s weekday, this week of a two-week schedule, no lunch', () {
      final domain = ManagerDashboardDataService.startHoursDomain(
        calendarIds: [1, 2],
        today: monday,
        fields: classicFields,
      );

      expect(domain, containsAll([
        ['calendar_id', 'in', [1, 2]],
        ['dayofweek', '=', '0'],
        ['day_period', '!=', 'lunch'],
      ]));
      expect(filteredFields(domain), contains('week_type'));
      expect(filteredFields(domain), isNot(contains('date')));
    });

    test('Odoo 20: fixed lines by weekday or dated lines by recurrence window', () {
      final domain = ManagerDashboardDataService.startHoursDomain(
        calendarIds: [1],
        today: monday,
        fields: odoo20Fields,
      );

      expect(filteredFields(domain), containsAll(['date', 'recurrency_until']));
      expect(filteredFields(domain), isNot(contains('week_type')));
      expect(domain, contains(equals(['date', '<=', '2026-10-19'])));
      expect(domain, contains(equals(['recurrency_until', '>=', '2026-10-19'])));
    });

    test(
      'duration_based without dated lines is not Odoo 20: never filters on '
      'date or recurrency_until',
      () {
        /// What an Odoo 19 server returned in the field: `duration_based` is
        /// there, `date` is not, and filtering on it failed the whole query
        /// ("Invalid field resource.calendar.attendance.date"), which the
        /// Late Check-ins card showed as 0.
        const odoo19Fields = {
          'dayofweek',
          'hour_from',
          'day_period',
          'week_type',
          'duration_hours',
          'duration_based',
        };

        final domain = ManagerDashboardDataService.startHoursDomain(
          calendarIds: [1],
          today: monday,
          fields: odoo19Fields,
        );

        expect(filteredFields(domain), isNot(contains('date')));
        expect(filteredFields(domain), isNot(contains('recurrency_until')));
        expect(filteredFields(domain), contains('dayofweek'));
      },
    );

    test('a server without week_type or day_period is not asked about them', () {
      final domain = ManagerDashboardDataService.startHoursDomain(
        calendarIds: [1],
        today: monday,
        fields: {'dayofweek', 'hour_from'},
      );

      expect(filteredFields(domain), {'calendar_id', 'dayofweek'});
    });

    test('Odoo 17-19: a line limited to a period only counts inside it', () {
      /// Otherwise an early line that starts tomorrow, or ended last week,
      /// pulls the start of today's day back and makes on-time check-ins late.
      final domain = ManagerDashboardDataService.startHoursDomain(
        calendarIds: [1],
        today: monday,
        fields: classicFields,
      );

      expect(domain, contains(equals(['date_from', '=', false])));
      expect(domain, contains(equals(['date_from', '<=', '2026-10-19'])));
      expect(domain, contains(equals(['date_to', '=', false])));
      expect(domain, contains(equals(['date_to', '>=', '2026-10-19'])));
    });

    test('Odoo 20 has no date_from/date_to, so it is not asked about them', () {
      final domain = ManagerDashboardDataService.startHoursDomain(
        calendarIds: [1],
        today: monday,
        fields: odoo20Fields,
      );

      expect(filteredFields(domain), isNot(contains('date_from')));
      expect(filteredFields(domain), isNot(contains('date_to')));
    });
  });

  group('ManagerDashboardDataService.countLateCheckIns', () {
    /// 09:15 and 07:50 on the device's clock.
    final nineFifteen = DateTime(2026, 10, 19, 9, 15);
    final sevenFifty = DateTime(2026, 10, 19, 7, 50);

    int count(
      Map<int, DateTime> firstCheckIn, {
      Map<int, int> calendarOf = const {1: 10, 2: 10, 3: 20},
      Map<int, double> startHours = const {10: 8.0, 20: 8.0},
      Set<int> flexible = const {},
    }) => ManagerDashboardDataService.countLateCheckIns(
      firstCheckIn: firstCheckIn,
      calendarOf: calendarOf,
      startHours: startHours,
      flexibleCalendars: flexible,
    );

    test('counts check-ins after the start of the day, not before it', () {
      expect(count({1: nineFifteen, 2: sevenFifty}), 1);
    });

    test('a check-in exactly at the start is not late', () {
      expect(count({1: DateTime(2026, 10, 19, 8, 0)}), 0);
      expect(count({1: DateTime(2026, 10, 19, 8, 1)}), 1);
    });

    test('an employee on a flexible schedule is never late', () {
      /// Odoo 18/19 keep the weekly lines of a schedule switched to Flexible
      /// Hours, so without this a 10:30 check-in counted as two and a half
      /// hours late.
      expect(count({1: nineFifteen, 3: nineFifteen}, flexible: {20}), 1);
      expect(count({3: nineFifteen}, flexible: {20}), 0);
    });

    test('an employee whose schedule has no start today is never late', () {
      expect(count({1: nineFifteen}, startHours: const {}), 0);
    });

    test('an employee with no schedule is never late', () {
      expect(count({9: nineFifteen}), 0);
    });
  });

  group('ManagerDashboardDataService.startHoursReadFields', () {
    test('reads only the fields this server has', () {
      expect(
        ManagerDashboardDataService.startHoursReadFields({
          'dayofweek',
          'hour_from',
          'duration_hours',
          'duration_based',
        }),
        ['calendar_id', 'hour_from', 'duration_hours', 'duration_based', 'dayofweek'],
      );
    });

    test('asks for the dated-line fields only when the server has them', () {
      final fields = ManagerDashboardDataService.startHoursReadFields({
        'duration_based',
        'dayofweek',
        'date',
        'recurrency',
        'recurrency_until',
      });

      expect(fields, containsAll(['date', 'recurrency', 'recurrency_until']));
      expect(fields, isNot(contains('recurrency_type')));
    });

    test('falls back to the two fields every version has', () {
      expect(
        ManagerDashboardDataService.startHoursReadFields(<String>{}),
        ['calendar_id', 'hour_from'],
      );
    });
  });
}
