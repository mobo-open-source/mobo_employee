import 'dart:async';

import 'package:flutter_test/flutter_test.dart';

import 'fake_manager_approvals_provider.dart';

/// Records how the calendar was asked to fetch, and holds the reply back.
class _SpyProvider extends FakeManagerApprovalsProvider {
  /// The `showLoader` of each fetch, in order.
  final List<bool> loaderRequests = [];
  Completer<void>? held;

  @override
  Future<void> fetchLeaveCalendarEventsFunction({
    bool showLoader = true,
  }) async {
    loaderRequests.add(showLoader);
    await held?.future;
  }
}

void main() {
  late _SpyProvider provider;

  setUp(() {
    provider = _SpyProvider();
    addTearDown(provider.dispose);
  });

  test('next month refetches without the loader, so no shimmer', () async {
    await provider.goToNextMonth();

    expect(provider.loaderRequests, [false]);
  });

  test('previous month refetches without the loader too', () async {
    await provider.goToPreviousMonth();

    expect(provider.loaderRequests, [false]);
  });

  test('the month and the listeners move before the reply arrives', () async {
    provider.held = Completer<void>();
    final start = provider.currentMonth;
    var notified = 0;
    provider.addListener(() => notified++);

    final moving = provider.goToNextMonth();

    expect(provider.currentMonth, DateTime(start.year, start.month + 1));
    expect(notified, greaterThan(0));
    expect(provider.isCalendarLoading, isFalse);

    provider.held!.complete();
    await moving;
  });
}
