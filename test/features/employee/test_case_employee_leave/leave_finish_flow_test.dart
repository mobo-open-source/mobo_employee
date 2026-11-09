import 'dart:async';

import 'package:flutter_test/flutter_test.dart';

import 'fake_employee_leave_provider.dart';

/// Records when the lists were reloaded, and lets the test hold the answer.
class _Provider extends FakeEmployeeLeaveProvider {
  final Completer<void> reload = Completer<void>();
  var reloads = 0;

  @override
  Future<void> refreshInPlace() async {
    reloads++;
    await reload.future;
  }
}

void main() {
  late _Provider provider;

  setUp(() {
    provider = _Provider();
    addTearDown(provider.dispose);
  });

  test(
    'reloads the lists at once, without waiting for the sheet to go',
    () async {
      provider.leaveTypeController.text = 'Casual Leave';

      final finishing = provider.finishLeaveRequest(
        closeDelay: const Duration(milliseconds: 100),
      );

      expect(provider.reloads, 1);
      provider.reload.complete();
      await finishing;
    },
  );

  test('keeps the form while the sheet slides away, then empties it', () async {
    provider.leaveTypeController.text = 'Casual Leave';
    provider.descriptionController.text = 'Family event';
    provider.reload.complete();

    final finishing = provider.finishLeaveRequest(
      closeDelay: const Duration(milliseconds: 100),
    );

    // Still on its way down: the fields stay as they were.
    expect(provider.leaveTypeController.text, 'Casual Leave');
    expect(provider.descriptionController.text, 'Family event');

    await finishing;

    expect(provider.leaveTypeController.text, isEmpty);
    expect(provider.descriptionController.text, isEmpty);
    expect(provider.modelTimeOffType, isNull);
  });

  test('the form is emptied even while the reload is still running', () async {
    provider.leaveTypeController.text = 'Casual Leave';

    final finishing = provider.finishLeaveRequest(
      closeDelay: const Duration(milliseconds: 50),
    );
    // The reload never answers, yet the form empties once the sheet has gone.
    await Future<void>.delayed(const Duration(milliseconds: 150));
    expect(provider.leaveTypeController.text, isEmpty);

    provider.reload.complete();
    await finishing;
  });
}
