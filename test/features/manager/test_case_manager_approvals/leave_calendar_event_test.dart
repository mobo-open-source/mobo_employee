import 'package:flutter_test/flutter_test.dart';
import 'package:mobo_employees/features/manager/manager_approvals/models/model_leave_calendar_event.dart';

void main() {
  group('LeaveCalendarEvent.fromJson', () {
    test('Odoo 20 request dates are plain, inclusive calendar days', () {
      final event = LeaveCalendarEvent.fromJson({
        'id': 2,
        'display_name': 'Admin Ser on STO: 3 days (10/26/2026 to 10/28/2026)',
        'state': 'validate',
        'request_date_from': '2026-10-26',
        'request_date_to': '2026-10-28',
        'duration_display': '3 days',
      });

      expect(event.dateFrom, DateTime(2026, 10, 26));
      expect(event.dateTo, DateTime(2026, 10, 28));
      expect(event.durationDisplay, '3 days');
    });

    test('Odoo 18/19 datetimes are UTC and converted to local time', () {
      final event = LeaveCalendarEvent.fromJson({
        'id': 1,
        'display_name': 'Anita on PTO',
        'state': 'validate',
        'start_datetime': '2026-10-25 18:30:00',
        'stop_datetime': '2026-10-28 10:30:00',
      });

      expect(event.dateFrom, DateTime.utc(2026, 10, 25, 18, 30).toLocal());
      expect(event.dateTo, DateTime.utc(2026, 10, 28, 10, 30).toLocal());
    });

    test('missing dates stay null instead of throwing', () {
      final event = LeaveCalendarEvent.fromJson({
        'id': 3,
        'display_name': false,
        'state': 'confirm',
        'start_datetime': false,
        'stop_datetime': null,
      });

      expect(event.dateFrom, isNull);
      expect(event.dateTo, isNull);
    });
  });
}
