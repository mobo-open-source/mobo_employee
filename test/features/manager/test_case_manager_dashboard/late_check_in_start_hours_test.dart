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
}
