import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mobo_employees/features/manager/manager_approvals/models/model_allocation_data.dart';
import 'package:mobo_employees/features/manager/manager_approvals/providers/manager_approvals_provider.dart';
import 'package:mobo_employees/features/manager/manager_approvals/widgets/app_shimmer.dart';
import 'package:mobo_employees/features/manager/manager_approvals/widgets/widget_manager_allocation_view_page.dart';
import 'package:mobo_employees/features/manager/manager_approvals/widgets/widget_timeoff_card.dart';
import 'package:mobo_employees/shared/widgets/loaders/loading_widget.dart';
import 'package:provider/provider.dart';

import 'fake_manager_approvals_provider.dart';

/// Answers allocation reads only when the test says so.
class _Provider extends FakeManagerApprovalsProvider {
  final List<Completer<List<ModelAllocationData>>> replies = [];

  @override
  Future<List<ModelAllocationData>> readAllocations() {
    final reply = Completer<List<ModelAllocationData>>();
    replies.add(reply);
    return reply.future;
  }
}

ModelAllocationData _row(int id) => ModelAllocationData(
  id: id,
  userId: id,
  employeeId: id,
  employeeName: 'Employee $id',
  leaveTypeName: 'Paid Time Off',
  durationDisplay: '5 days',
  maxLeaves: 5,
  notes: 'Note $id',
  remainingLeaves: 5,
  createDate: DateTime(2026, 3, 1),
  createDateFormatted: '03/01/2026',
  state: 'confirm',
  canApprove: true,
  canValidate: true,
  canRefuse: true,
);

List<int> _ids(ManagerApprovalsProvider p) =>
    p.allocationList.map((a) => a.id).toList();

void main() {
  late _Provider provider;

  setUp(() {
    provider = _Provider();
    addTearDown(provider.dispose);
  });

  group('reading the allocations', () {
    test('the first read raises the loader until it answers', () async {
      final read = provider.fetchAllocationDetails();
      expect(provider.isAllocationLoading, isTrue);

      provider.replies.single.complete([_row(1)]);
      await read;

      expect(provider.isAllocationLoading, isFalse);
      expect(_ids(provider), [1]);
    });

    test(
      'every later read happens in place, over the list on screen',
      () async {
        var everLoading = false;
        var shownDuringRead = <int>[];

        final first = provider.fetchAllocationDetails();
        provider.replies[0].complete([_row(1)]);
        await first;

        provider.addListener(() {
          if (provider.isAllocationLoading) everLoading = true;
        });

        final second = provider.fetchAllocationDetails();
        // While the new answer is on its way the old list is still there.
        shownDuringRead = _ids(provider);
        expect(provider.isAllocationLoading, isFalse);

        provider.replies[1].complete([_row(2)]);
        await second;

        expect(shownDuringRead, [1]);
        expect(_ids(provider), [2]);
        expect(everLoading, isFalse);
      },
    );

    test('a retry after a failure shows the loader again', () async {
      final failed = provider.fetchAllocationDetails();
      provider.replies[0].completeError(Exception('offline'));
      await failed;
      expect(provider.allocationLoadError, isNotNull);

      final retry = provider.fetchAllocationDetails();
      expect(provider.isAllocationLoading, isTrue);
      expect(provider.allocationLoadError, isNull);

      provider.replies[1].complete([_row(1)]);
      await retry;
      expect(provider.isAllocationLoading, isFalse);
    });

    test('a reply that has been overtaken is dropped', () async {
      final first = provider.fetchAllocationDetails();
      provider.replies[0].complete([_row(1)]);
      await first;

      final older = provider.fetchAllocationDetails();
      final newer = provider.fetchAllocationDetails();

      provider.replies[2].complete([_row(3)]);
      await newer;
      provider.replies[1].complete([_row(2)]);
      await older;

      expect(_ids(provider), [3]);
    });

    test('switching company starts cold again', () async {
      final first = provider.fetchAllocationDetails();
      provider.replies[0].complete([_row(1)]);
      await first;

      provider.clearOnManagerLogout();
      expect(provider.allocationList, isEmpty);

      final again = provider.fetchAllocationDetails();
      expect(provider.isAllocationLoading, isTrue);
      provider.replies[1].complete([_row(2)]);
      await again;
    });
  });

  group('the Allocation tab', () {
    Widget page() => ChangeNotifierProvider<ManagerApprovalsProvider>.value(
      value: provider,
      child: const MaterialApp(
        home: Scaffold(body: WidgetManagerAllocationViewPage()),
      ),
    );

    testWidgets('never shows the card shimmer — not even on the first read', (
      tester,
    ) async {
      await tester.pumpWidget(page());

      final read = provider.fetchAllocationDetails();
      await tester.pump();
      expect(find.byType(WidgetTimeOffCardShimmer), findsNothing);
      // A small loader stands in, instead of a screenful of skeleton cards.
      expect(find.byType(LoadingWidget), findsOneWidget);

      provider.replies[0].complete([_row(1), _row(2)]);
      await read;
      await tester.pump();

      expect(find.byType(LoadingWidget), findsNothing);
      expect(find.byType(WidgetTimeOffCardShimmer), findsNothing);
      expect(find.byType(WidgetTimeOffCard), findsNWidgets(2));
    });

    testWidgets('tapping the tab again keeps the cards on screen', (
      tester,
    ) async {
      await tester.pumpWidget(page());
      final first = provider.fetchAllocationDetails();
      provider.replies[0].complete([_row(1), _row(2)]);
      await first;
      await tester.pump();
      expect(find.byType(WidgetTimeOffCard), findsNWidgets(2));

      // The tab is selected again: it reads again, but nothing flickers.
      final again = provider.fetchAllocationDetails();
      await tester.pump();
      expect(find.byType(WidgetTimeOffCardShimmer), findsNothing);
      expect(find.byType(LoadingWidget), findsNothing);
      expect(find.byType(WidgetTimeOffCard), findsNWidgets(2));

      provider.replies[1].complete([_row(3)]);
      await again;
      await tester.pump();
      expect(find.byType(WidgetTimeOffCard), findsOneWidget);
      expect(find.text('Employee 3'), findsOneWidget);
    });
  });
}
