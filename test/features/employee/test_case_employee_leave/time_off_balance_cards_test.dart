import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mobo_employees/features/employee/leave/model/model_time_off_balance.dart';
import 'package:mobo_employees/features/employee/leave/widget/time_off_balance_cards.dart';
import 'package:mobo_employees/features/manager/manager_approvals/widgets/widget_card.dart';

TimeOffBalance _balance(int id, String name) => TimeOffBalance(
  typeId: id,
  name: name,
  requiresAllocation: true,
  amount: 20,
  isHours: false,
  validity: '12/31/2026',
);

/// The cards inside a Column that centres its children, as the Approvals page
/// does — the case that used to float a short row into the middle.
Widget _cards(List<TimeOffBalance> balances) {
  return MaterialApp(
    home: Scaffold(
      body: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 15),
        child: Column(
          children: [
            TimeOffBalanceCards(
              balances: balances,
              pendingCount: 1,
              pendingSubtitle: 'Allocation requests',
            ),
          ],
        ),
      ),
    ),
  );
}

void main() {
  testWidgets('a lone card starts at the left, not in the middle', (
    tester,
  ) async {
    // No balances: just the Pending card.
    await tester.pumpWidget(_cards(const []));

    expect(find.byType(DashboardStatCard), findsOneWidget);
    expect(tester.getRect(find.byType(DashboardStatCard)).left, 15);
  });

  testWidgets(
    'a couple of cards that do not fill the row start at the left too',
    (tester) async {
      await tester.pumpWidget(_cards([_balance(1, 'Paid Time Off')]));

      final cards = find.byType(DashboardStatCard);
      expect(cards, findsNWidgets(2));
      expect(tester.getRect(cards.first).left, 15);
      // ...side by side, 8 apart.
      expect(
        tester.getRect(cards.last).left - tester.getRect(cards.first).right,
        8,
      );
    },
  );

  testWidgets('more cards than fit still scroll from the start', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(400, 800);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(
      _cards([
        _balance(1, 'Paid Time Off'),
        _balance(2, 'Compensatory Days'),
        _balance(3, 'Training'),
      ]),
    );

    expect(tester.getRect(find.byType(DashboardStatCard).first).left, 15);
    expect(tester.takeException(), isNull);

    // The row scrolls: the last card is reachable by dragging.
    await tester.drag(
      find.byType(SingleChildScrollView),
      const Offset(-300, 0),
    );
    await tester.pump();
    expect(
      tester.getRect(find.byType(DashboardStatCard).first).left,
      lessThan(15),
    );
  });
}
