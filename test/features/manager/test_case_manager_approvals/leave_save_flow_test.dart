import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:mobo_employees/features/manager/manager_approvals/models/model_time_off_add_time_off_type.dart';
import 'package:mobo_employees/features/manager/manager_approvals/models/model_timeoff_data.dart';
import 'package:mobo_employees/features/manager/manager_approvals/providers/manager_approvals_provider.dart';

/// The real provider, with Odoo stood in for — and the test deciding when each
/// answer arrives. (Not the shared fake: that stubs out `fetchTimeOffDetails`
/// itself, which is what is being tested.)
class _Provider extends ManagerApprovalsProvider {
  final List<Completer<List<ModelTimeOffData>>> reads = [];
  final List<Map<String, dynamic>> created = [];

  @override
  Future<List<ModelTimeOffData>> readTimeOff() {
    final reply = Completer<List<ModelTimeOffData>>();
    reads.add(reply);
    return reply.future;
  }

  @override
  Future<void> createLeaveRecord(Map<String, dynamic> values) async =>
      created.add(values);

  @override
  Future<int> leaveServerMajorVersion() async => 19;

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
  leaveTypeName: 'Casual Leave',
  durationDisplay: '1 day',
  dateFrom: DateTime(2026, 11, 10),
  dateTo: DateTime(2026, 11, 10),
  dateFromFormatted: '11/10/2026',
  dateToFormatted: '11/10/2026',
  create_date: '11/06/2026',
  state: 'confirm',
  canApprove: true,
  canValidate: true,
  canRefuse: true,
);

List<int> _ids(_Provider p) => p.timeOffList.map((e) => e.id).toList();

/// A complete Apply for Leave form.
void _fillForm(_Provider p) {
  p.selectedEmployeeId = 5;
  p.employeeController.text = 'Mitchell Admin';
  p.leaveTypes.add(ModelTimeOffAddTimeOffType(id: 3, name: 'Casual Leave'));
  p.leaveTypeController.text = 'Casual Leave';
  p.descriptionController.text = 'Family event';
  p.fromDate = DateTime(2026, 11, 10);
  p.toDate = DateTime(2026, 11, 11);
}

void main() {
  late _Provider provider;

  setUp(() {
    provider = _Provider();
    addTearDown(provider.dispose);
  });

  group('the Time Off list', () {
    test('the first read raises the loader until it answers', () async {
      final read = provider.fetchTimeOffDetails();
      expect(provider.isTimeOffLoading, isTrue);

      provider.reads.single.complete([_row(1)]);
      await read;

      expect(provider.isTimeOffLoading, isFalse);
      expect(_ids(provider), [1]);
    });

    test(
      'every later read happens in place, over the list on screen',
      () async {
        final first = provider.fetchTimeOffDetails();
        provider.reads[0].complete([_row(1)]);
        await first;

        var everLoading = false;
        provider.addListener(() {
          if (provider.isTimeOffLoading) everLoading = true;
        });

        final second = provider.fetchTimeOffDetails();
        expect(provider.isTimeOffLoading, isFalse);
        // The old list is still there while the new one is on its way.
        expect(_ids(provider), [1]);

        provider.reads[1].complete([_row(1), _row(2)]);
        await second;

        expect(_ids(provider), [1, 2]);
        expect(everLoading, isFalse);
      },
    );

    test('a retry after a failure shows the loader again', () async {
      final failed = provider.fetchTimeOffDetails();
      provider.reads[0].completeError(Exception('offline'));
      await failed;
      expect(provider.timeOffLoadError, isNotNull);

      final retry = provider.fetchTimeOffDetails();
      expect(provider.isTimeOffLoading, isTrue);
      provider.reads[1].complete([_row(1)]);
      await retry;
      expect(provider.isTimeOffLoading, isFalse);
    });

    test('a reply that has been overtaken is dropped', () async {
      final first = provider.fetchTimeOffDetails();
      provider.reads[0].complete([_row(1)]);
      await first;

      final older = provider.fetchTimeOffDetails();
      final newer = provider.fetchTimeOffDetails();
      provider.reads[2].complete([_row(3)]);
      await newer;
      provider.reads[1].complete([_row(2)]);
      await older;

      expect(_ids(provider), [3]);
    });
  });

  group('saving an Apply for Leave', () {
    /// Warm: the Time Off list has been read once, as it has by the time
    /// someone is applying for leave from that tab.
    Future<void> warm() async {
      final first = provider.fetchTimeOffDetails();
      provider.reads[0].complete([_row(1)]);
      await first;
    }

    test(
      'returns as soon as the request is created, without waiting for the reload',
      () async {
        await warm();
        _fillForm(provider);

        // The list's reload (reads[1]) is left unanswered: if the save waited for
        // it, this would never return.
        final result = await provider.saveLeave().timeout(
          const Duration(seconds: 2),
        );

        expect(result, isNull);
        expect(provider.created, hasLength(1));
        expect(provider.created.single['employee_id'], 5);
        expect(provider.reads, hasLength(2), reason: 'the reload has started');
        expect(provider.reads[1].isCompleted, isFalse);

        // Let the clean-up that follows run to its end before the test does.
        provider.reads[1].complete([_row(1)]);
        await Future<void>.delayed(const Duration(milliseconds: 450));
      },
    );

    test('does not flash the Time Off shimmer behind the sheet', () async {
      await warm();
      _fillForm(provider);

      var everLoading = false;
      provider.addListener(() {
        if (provider.isTimeOffLoading) everLoading = true;
      });

      await provider.saveLeave();
      provider.reads[1].complete([_row(1), _row(2)]);
      await Future<void>.delayed(const Duration(milliseconds: 450));

      expect(everLoading, isFalse);
      expect(_ids(provider), [1, 2]);
    });

    test(
      'leaves the form alone while the sheet slides away, then empties it',
      () async {
        await warm();
        _fillForm(provider);

        await provider.saveLeave();

        // Just closed: the sheet is still on its way down, so its fields stay.
        expect(provider.leaveTypeController.text, 'Casual Leave');
        expect(provider.descriptionController.text, 'Family event');
        expect(provider.employeeController.text, 'Mitchell Admin');

        provider.reads[1].complete([_row(1)]);
        await Future<void>.delayed(const Duration(milliseconds: 450));

        // The sheet has gone: the form is blank for next time.
        expect(provider.leaveTypeController.text, isEmpty);
        expect(provider.descriptionController.text, isEmpty);
        expect(provider.employeeController.text, isEmpty);
        expect(provider.selectedEmployeeId, isNull);
      },
    );

    test(
      'an invalid form is reported and nothing is created or reloaded',
      () async {
        await warm();
        _fillForm(provider);
        provider.selectedEmployeeId = null;

        final result = await provider.saveLeave();

        expect(result, 'Select employee');
        expect(provider.created, isEmpty);
        expect(provider.reads, hasLength(1));
        // The form is still there to fix.
        expect(provider.leaveTypeController.text, 'Casual Leave');
      },
    );
  });
}
