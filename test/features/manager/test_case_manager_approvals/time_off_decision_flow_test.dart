import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mobo_employees/features/manager/manager_approvals/models/model_timeoff_data.dart';
import 'package:mobo_employees/features/manager/manager_approvals/providers/manager_approvals_provider.dart';
import 'package:mobo_employees/features/manager/manager_approvals/widgets/app_shimmer.dart';
import 'package:mobo_employees/features/manager/manager_approvals/widgets/widget_manager_time_off_view_page.dart';
import 'package:mobo_employees/features/manager/manager_approvals/widgets/widget_timeoff_card.dart';
import 'package:provider/provider.dart';

/// The real provider with Odoo stood in for, and the test deciding when each
/// answer arrives.
class _Provider extends ManagerApprovalsProvider {
  final List<Completer<List<ModelTimeOffData>>> reads = [];
  final List<String> decisions = [];

  @override
  Future<List<ModelTimeOffData>> readTimeOff() {
    final reply = Completer<List<ModelTimeOffData>>();
    reads.add(reply);
    return reply.future;
  }

  @override
  Future<void> decideTimeOff(String decision, int leaveId) async =>
      decisions.add('$decision $leaveId');

  // The calendar's counters are not what is being tested here.
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
  state: 'confirm',
  canApprove: true,
  canValidate: true,
  canRefuse: true,
);

List<int> _ids(_Provider p) => p.timeOffList.map((e) => e.id).toList();

Widget _page(_Provider provider) {
  return ChangeNotifierProvider<ManagerApprovalsProvider>.value(
    value: provider,
    child: const MaterialApp(
      home: Scaffold(body: WidgetManagerTimeOffViewPage()),
    ),
  );
}

void main() {
  late _Provider provider;

  setUp(() {
    provider = _Provider();
    addTearDown(provider.dispose);
  });

  group('the provider', () {
    /// The list read once, as it has been by the time someone is deciding on
    /// a request in it.
    Future<void> warm() async {
      final first = provider.fetchTimeOffDetails();
      provider.reads[0].complete([_row(1), _row(2)]);
      await first;
    }

    test('Validate reloads the list in place — the loader never rises', () async {
      await warm();
      var everLoading = false;
      provider.addListener(() {
        if (provider.isTimeOffLoading) everLoading = true;
      });

      final deciding = provider.validateTimeOff(_Ctx.of(), 1, 'confirm');
      await Future<void>.delayed(Duration.zero);
      // While Odoo is being asked and the list re-read, the list is still there.
      expect(provider.isTimeOffLoading, isFalse);
      expect(_ids(provider), [1, 2]);

      provider.reads[1].complete([_row(2)]);
      await deciding;

      expect(provider.decisions, ['approve 1']);
      expect(_ids(provider), [2]);
      expect(everLoading, isFalse);
    });

    test('a second-level request is validated, not just approved', () async {
      await warm();

      final deciding = provider.validateTimeOff(_Ctx.of(), 1, 'validate1');
      await Future<void>.delayed(Duration.zero);
      provider.reads[1].complete([_row(2)]);
      await deciding;

      expect(provider.decisions, ['validate 1']);
    });

    test('Refuse reloads the list in place too', () async {
      await warm();
      var everLoading = false;
      provider.addListener(() {
        if (provider.isTimeOffLoading) everLoading = true;
      });

      final deciding = provider.refuseTimeOff(_Ctx.of(), 2);
      await Future<void>.delayed(Duration.zero);
      expect(provider.isTimeOffLoading, isFalse);

      provider.reads[1].complete([_row(1)]);
      await deciding;

      expect(provider.decisions, ['refuse 2']);
      expect(_ids(provider), [1]);
      expect(everLoading, isFalse);
    });
  });

  group('the Time Off page', () {
    final shimmer = find.byType(WidgetTimeOffCardShimmer);

    testWidgets('never shows the list shimmer while a request is validated', (
      tester,
    ) async {
      await tester.pumpWidget(_page(provider));

      // The first read: a shimmer is fine here, there is nothing to show yet.
      final first = provider.fetchTimeOffDetails();
      await tester.pump();
      expect(shimmer, findsWidgets);
      provider.reads[0].complete([_row(1), _row(2)]);
      await first;
      await tester.pump();
      expect(shimmer, findsNothing);
      expect(find.byType(WidgetTimeOffCard), findsNWidgets(2));

      // Validate the first one.
      await tester.tap(find.text('Validate').first);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));

      // Odoo is being asked and the list re-read: the cards stay, none of them
      // turn into a shimmer.
      expect(shimmer, findsNothing, reason: 'while the list reloads');
      expect(find.byType(WidgetTimeOffCard), findsNWidgets(2));

      provider.reads[1].complete([_row(2)]);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));

      expect(shimmer, findsNothing, reason: 'once it has reloaded');
      expect(find.byType(WidgetTimeOffCard), findsOneWidget);
      expect(find.text('Employee 2'), findsOneWidget);
      expect(provider.decisions, ['approve 1']);
    });

    testWidgets('never shows the list shimmer while a request is refused', (
      tester,
    ) async {
      await tester.pumpWidget(_page(provider));
      final first = provider.fetchTimeOffDetails();
      provider.reads[0].complete([_row(1), _row(2)]);
      await first;
      await tester.pump();

      await tester.tap(find.text('Refuse').last);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));
      expect(shimmer, findsNothing, reason: 'while the list reloads');
      expect(find.byType(WidgetTimeOffCard), findsNWidgets(2));

      provider.reads[1].complete([_row(1)]);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));

      expect(shimmer, findsNothing, reason: 'once it has reloaded');
      expect(find.byType(WidgetTimeOffCard), findsOneWidget);
      expect(provider.decisions, ['refuse 2']);
    });
  });
}

/// A context for the provider's methods, which take one but never use it here.
class _Ctx {
  static BuildContext of() => _NoContext();
}

class _NoContext implements BuildContext {
  @override
  dynamic noSuchMethod(Invocation invocation) => null;
}
