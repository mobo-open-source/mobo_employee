import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mobo_employees/features/employee/leave/widget/time_off_balance_cards.dart';
import 'package:mobo_employees/features/manager/manager_approvals/providers/manager_approvals_provider.dart';
import 'package:mobo_employees/features/manager/manager_approvals/widgets/widget_card.dart';
import 'package:mobo_employees/features/manager/manager_approvals/widgets/widget_manager_calender_view_page.dart';
import 'package:mobo_employees/shared/widgets/calendar/leave_month_calendar.dart';
import 'package:provider/provider.dart';

import 'fake_manager_approvals_provider.dart';

/// The Calendar tab as the Approvals page hosts it.
Widget _page(ManagerApprovalsProvider provider) {
  return ChangeNotifierProvider<ManagerApprovalsProvider>.value(
    value: provider,
    child: const MaterialApp(
      home: Scaffold(
        body: Padding(
          padding: EdgeInsets.symmetric(horizontal: 15),
          child: WidgetManagerCalenderViewPage(),
        ),
      ),
    ),
  );
}

/// The heading of the fake provider's 10 March 2026 requests panel.
const _panelHeading = 'Tue, Mar 10, 2026';

void main() {
  late FakeManagerApprovalsProvider provider;

  setUp(() {
    provider = FakeManagerApprovalsProvider();
    addTearDown(provider.dispose);
  });

  testWidgets(
    'shows the calendar, and no requests panel until a day is picked',
    (tester) async {
      await tester.pumpWidget(_page(provider));

      expect(find.byType(LeaveMonthCalendar), findsOneWidget);
      expect(find.text(_panelHeading), findsNothing);
    },
  );

  testWidgets('the picked day\'s requests sit below the calendar', (
    tester,
  ) async {
    await tester.pumpWidget(_page(provider));

    provider.selectDate(DateTime(2026, 3, 10));
    await tester.pumpAndSettle();

    final cards = tester.getRect(find.byType(TimeOffBalanceCards));
    final calendar = tester.getRect(find.byType(LeaveMonthCalendar));
    final panel = tester.getRect(find.text(_panelHeading));

    // Balance cards, then the calendar, then the requests.
    expect(calendar.top, greaterThanOrEqualTo(cards.bottom));
    expect(panel.top, greaterThanOrEqualTo(calendar.bottom));
    // Both requests of that day are listed.
    expect(find.text('Casual Leave Description'), findsWidgets);
  });

  testWidgets('on a short screen it scrolls down to the requests', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(400, 560);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(_page(provider));
    provider.selectDate(DateTime(2026, 3, 10));
    await tester.pumpAndSettle();

    // The panel is in view: its heading is on screen, not past the bottom.
    final heading = tester.getRect(find.text(_panelHeading));
    expect(heading.top, greaterThanOrEqualTo(0));
    expect(heading.bottom, lessThanOrEqualTo(560));
  });

  testWidgets('the balance card starts at the left, not in the middle', (
    tester,
  ) async {
    // The fake has no balances, so the row is the one Pending card.
    await tester.pumpWidget(_page(provider));

    final cards = find.byType(DashboardStatCard);
    expect(cards, findsOneWidget);
    expect(tester.getRect(cards).left, 15);
  });

  testWidgets(
    'the picked day\'s requests carry no status text — the dot says it',
    (tester) async {
      await tester.pumpWidget(_page(provider));
      provider.selectDate(DateTime(2026, 3, 10));
      await tester.pumpAndSettle();

      // Both of 10 March's requests are listed (one validated)...
      expect(find.text('Casual Leave Description'), findsWidgets);
      // ...and "Validated" / "To Approve" appear once each: in the calendar's
      // legend, no longer again on the right of every request.
      expect(find.text('Validated'), findsOneWidget);
      expect(find.text('To Approve'), findsOneWidget);
      expect(find.text('Refused'), findsOneWidget);
      expect(find.text('Cancelled'), findsNothing);
      expect(find.text('Second Approval'), findsNothing);
    },
  );

  testWidgets('closing the panel takes the requests away', (tester) async {
    await tester.pumpWidget(_page(provider));
    provider.selectDate(DateTime(2026, 3, 10));
    await tester.pumpAndSettle();
    expect(find.text(_panelHeading), findsOneWidget);

    await tester.tap(find.byTooltip('Close'));
    await tester.pumpAndSettle();

    expect(find.text(_panelHeading), findsNothing);
    expect(find.byType(LeaveMonthCalendar), findsOneWidget);
  });

  group('a day with no time off', () {
    const noTimeOff = 'No time off on this day';

    // The panel card around the message: the nearest bordered Container.
    Finder card() => find
        .ancestor(
          of: find.text(noTimeOff),
          matching: find.byWidgetPredicate(
            (w) =>
                w is Container &&
                w.decoration is BoxDecoration &&
                (w.decoration! as BoxDecoration).border != null,
          ),
        )
        .first;

    testWidgets('gives the message room under the heading\'s line', (
      tester,
    ) async {
      await tester.pumpWidget(_page(provider));
      provider.selectDate(DateTime(2026, 3, 25));
      await tester.pumpAndSettle();

      expect(find.text(noTimeOff), findsOneWidget);
      final line = tester.getRect(
        find.descendant(of: card(), matching: find.byType(Divider)),
      );
      final text = tester.getRect(find.text(noTimeOff));
      // The divider's box is 12 tall around its 1px line, so it already leaves
      // 5.5 under the line; the message's 12 of top padding comes on top.
      expect(text.top - line.bottom, greaterThanOrEqualTo(12));
    });

    testWidgets('and above the card\'s bottom edge', (tester) async {
      await tester.pumpWidget(_page(provider));
      provider.selectDate(DateTime(2026, 3, 25));
      await tester.pumpAndSettle();

      final text = tester.getRect(find.text(noTimeOff));
      final box = tester.getRect(card());
      expect(box.bottom - text.bottom, greaterThanOrEqualTo(18));
    });

    testWidgets('the card with requests is not made any taller', (
      tester,
    ) async {
      await tester.pumpWidget(_page(provider));
      provider.selectDate(DateTime(2026, 3, 10));
      await tester.pumpAndSettle();

      // Only the empty message was given extra room: with requests the panel is
      // as it was — its first row is 6px under the heading's line.
      expect(find.text(noTimeOff), findsNothing);
      final line = tester.getRect(
        find
            .descendant(
              of: find
                  .ancestor(
                    of: find.text('Casual Leave Description').first,
                    matching: find.byWidgetPredicate(
                      (w) =>
                          w is Container &&
                          w.decoration is BoxDecoration &&
                          (w.decoration! as BoxDecoration).border != null,
                    ),
                  )
                  .first,
              matching: find.byType(Divider),
            )
            .first,
      );
      final row = tester.getRect(find.text('Casual Leave Description').first);
      expect(row.top - line.bottom, lessThan(16));
    });
  });
}
