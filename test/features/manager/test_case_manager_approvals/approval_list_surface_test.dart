import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mobo_employees/features/manager/manager_approvals/models/model_timeoff_data.dart';
import 'package:mobo_employees/features/manager/manager_approvals/providers/manager_approvals_provider.dart';
import 'package:mobo_employees/features/manager/manager_approvals/widgets/widget_manager_time_off_view_page.dart';
import 'package:mobo_employees/features/manager/manager_approvals/widgets/widget_timeoff_card.dart';
import 'package:provider/provider.dart';

/// The real provider with Odoo stood in for: the Time Off list answers at once
/// with [rows].
class _Provider extends ManagerApprovalsProvider {
  final List<ModelTimeOffData> rows;
  _Provider(this.rows);

  @override
  Future<List<ModelTimeOffData>> readTimeOff() async => rows;

  @override
  Future<void> fetchLeaveCalendarEventsFunction({
    bool showLoader = true,
  }) async {}

  @override
  Future<void> fetchTimeOffData({bool showLoader = true}) async {}
}

ModelTimeOffData _row(int id) => ModelTimeOffData(
  id: id,
  employeeId: id,
  userId: id,
  employeeName: 'Employee $id',
  departmentId: 1,
  departmentName: 'R&D',
  description: 'Reason $id',
  leaveTypeName: 'Paid Time Off',
  durationDisplay: '1 day',
  dateFrom: DateTime(2026, 11, 6),
  dateTo: DateTime(2026, 11, 6),
  dateFromFormatted: '11/06/2026',
  dateToFormatted: '11/06/2026',
  create_date: '11/05/2026',
  state: 'validate',
  canApprove: false,
  canValidate: false,
  canRefuse: false,
);

/// The Time Off tab as the Approvals page now hosts it: with no side padding
/// of its own around the list.
Widget _tab(_Provider provider) {
  return ChangeNotifierProvider<ManagerApprovalsProvider>.value(
    value: provider,
    child: const MaterialApp(
      home: Scaffold(body: WidgetManagerTimeOffViewPage()),
    ),
  );
}

void main() {
  late _Provider provider;

  setUp(() async {
    provider = _Provider([_row(1), _row(2), _row(3)]);
    addTearDown(provider.dispose);
    await provider.fetchTimeOffDetails();
  });

  group('the Time Off list', () {
    testWidgets('keeps the 15 side inset inside the list, so the cards\' '
        'shadows are not clipped', (tester) async {
      await tester.pumpWidget(_tab(provider));

      final list = tester.getRect(find.byType(ListView));
      final card = tester.getRect(find.byType(WidgetTimeOffCard).first);

      // The list itself runs the full width...
      expect(list.left, 0);
      expect(list.right, 800);
      // ...and the card sits 15 in from each side, inside it: the shadow has
      // those 15 to spread into before the list's edge would cut it.
      expect(card.left - list.left, WidgetTimeOffCard.listSideInset);
      expect(list.right - card.right, WidgetTimeOffCard.listSideInset);
    });

    testWidgets('leaves 12 between cards, as the Employees list does', (
      tester,
    ) async {
      await tester.pumpWidget(_tab(provider));

      final cards = find.byType(WidgetTimeOffCard);
      final first = tester.getRect(cards.at(0));
      final second = tester.getRect(cards.at(1));
      expect(second.top - first.bottom, WidgetTimeOffCard.listGap);
      expect(WidgetTimeOffCard.listGap, 12);
    });

    testWidgets('every card wears the shared flat-card surface', (
      tester,
    ) async {
      await tester.pumpWidget(_tab(provider));

      final surfaces = tester
          .widgetList<Container>(
            find.descendant(
              of: find.byType(WidgetTimeOffCard),
              matching: find.byType(Container),
            ),
          )
          .where((c) => c.decoration == WidgetTimeOffCard.decoration(false));
      expect(surfaces, hasLength(3));
    });
  });

  test('the lists\' padding is the side inset, room above and room below', () {
    expect(
      WidgetTimeOffCard.listPadding(bottom: 80),
      const EdgeInsets.fromLTRB(15, 12, 15, 80),
    );
    expect(
      WidgetTimeOffCard.listPadding(),
      const EdgeInsets.fromLTRB(15, 12, 15, 12),
    );
  });
}
