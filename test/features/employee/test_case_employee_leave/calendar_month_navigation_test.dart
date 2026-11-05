import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:mobo_employees/features/employee/leave/model/leaveMyCalender.dart';
import 'package:mobo_employees/features/employee/leave/provider/leave_page_provider.dart';
import 'package:mobo_employees/features/employee/leave/service/leave_service.dart';

/// Answers calendar requests only when the test says so, so a reply can be held
/// back or made to arrive late.
class _HeldLeaveService extends LeaveService {
  final List<Completer<List<LeaveMyCalenderModel>>> pending = [];

  @override
  Future<List<LeaveMyCalenderModel>> fetchMyLeaveCalendarEvents({
    required DateTime from,
    required DateTime to,
  }) {
    final reply = Completer<List<LeaveMyCalenderModel>>();
    pending.add(reply);
    return reply.future;
  }
}

class _Provider extends LeavePageProvider {
  _Provider(this.service);

  final _HeldLeaveService service;

  @override
  LeaveService get services => service;
}

LeaveMyCalenderModel _leave(int id) => LeaveMyCalenderModel(
  id: id,
  description: 'Leave $id',
  leaveTypeName: 'Casual Leave',
  dateFrom: DateTime(2026, 3, 10),
  dateTo: DateTime(2026, 3, 10),
  dateFromFormatted: '10 Mar 2026',
  dateToFormatted: '10 Mar 2026',
  state: 'validate',
);

void main() {
  late _HeldLeaveService service;
  late _Provider provider;

  setUp(() {
    service = _HeldLeaveService();
    provider = _Provider(service);
    addTearDown(provider.dispose);
  });

  group('moving between months', () {
    test(
      'never raises the loading flag, so nothing flashes a shimmer',
      () async {
        var everLoading = false;
        provider.addListener(() {
          if (provider.isLoading) everLoading = true;
        });

        provider.goToNextMyMonth();
        expect(provider.isLoading, isFalse, reason: 'while the request is out');

        service.pending.single.complete([_leave(1)]);
        await pumpEventQueue();

        expect(everLoading, isFalse);
        expect(provider.isLoading, isFalse);
        expect(provider.calendarEvents.map((e) => e.id), [1]);
      },
    );

    test('previous month is just as quiet', () async {
      var everLoading = false;
      provider.addListener(() {
        if (provider.isLoading) everLoading = true;
      });

      provider.goToPreviousMyMonth();
      service.pending.single.complete([]);
      await pumpEventQueue();

      expect(everLoading, isFalse);
    });

    test('shows the new month straight away, before the reply', () {
      final start = provider.currentMonth;
      var notified = 0;
      provider.addListener(() => notified++);

      provider.goToNextMyMonth();

      expect(provider.currentMonth, DateTime(start.year, start.month + 1));
      expect(notified, greaterThan(0));
      // ...while the events are still on their way.
      expect(service.pending, hasLength(1));
    });

    test(
      'a slow reply for an earlier month does not overwrite a later one',
      () async {
        provider.goToNextMyMonth();
        provider.goToNextMyMonth();
        expect(service.pending, hasLength(2));

        // The later month answers first; the earlier one's reply limps in after.
        service.pending[1].complete([_leave(2)]);
        await pumpEventQueue();
        service.pending[0].complete([_leave(1)]);
        await pumpEventQueue();

        expect(provider.calendarEvents.map((e) => e.id), [2]);
      },
    );
  });

  test('a normal fetch still raises and lowers the loading flag', () async {
    final fetch = provider.fetchLeaveMyCalendarEventsFunction();
    expect(provider.isLoading, isTrue);

    service.pending.single.complete([_leave(1)]);
    await fetch;

    expect(provider.isLoading, isFalse);
    expect(provider.calendarEvents.map((e) => e.id), [1]);
  });
}
