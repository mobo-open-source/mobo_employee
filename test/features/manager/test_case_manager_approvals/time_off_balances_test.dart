import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:mobo_employees/core/services/odoo_session_manager.dart';
import 'package:mobo_employees/features/employee/leave/model/model_time_off_balance.dart';
import 'package:mobo_employees/features/manager/manager_approvals/providers/manager_approvals_provider.dart';

TimeOffBalance _balance(String name, double days) => TimeOffBalance(
  typeId: name.hashCode,
  name: name,
  requiresAllocation: true,
  amount: days,
  isHours: false,
  validity: null,
);

TimeOffDashboard _dashboard({int pending = 1}) => TimeOffDashboard(
  balances: [_balance('Paid Time Off', 20), _balance('Training Time Off', 7)],
  pendingAllocations: pending,
);

void main() {
  group('orderAllowedCompanies', () {
    test(
      'puts the active company first, which Odoo takes as the current one',
      () {
        // The list as the app keeps it: the active company (1) ticked last.
        expect(
          OdooSessionManager.orderAllowedCompanies(
            [4, 3, 1],
            1,
            activeFirst: true,
          ),
          [1, 4, 3],
        );
      },
    );

    test('keeps the saved order when asked not to reorder', () {
      expect(
        OdooSessionManager.orderAllowedCompanies(
          [4, 3, 1],
          1,
          activeFirst: false,
        ),
        [4, 3, 1],
      );
    });

    test('adds an active company missing from the list', () {
      expect(
        OdooSessionManager.orderAllowedCompanies([4, 3], 1, activeFirst: true),
        [1, 4, 3],
      );
      expect(
        OdooSessionManager.orderAllowedCompanies([4, 3], 1, activeFirst: false),
        [4, 3, 1],
      );
    });

    test('has no duplicates and works with an empty list', () {
      expect(
        OdooSessionManager.orderAllowedCompanies(
          [1, 1, 2],
          1,
          activeFirst: true,
        ),
        [1, 2],
      );
      expect(
        OdooSessionManager.orderAllowedCompanies([], 5, activeFirst: true),
        [5],
      );
    });
  });

  group('ManagerApprovalsProvider.fetchTimeOffData', () {
    test('shows the cards once they are read', () async {
      final provider = ManagerApprovalsProvider(
        readTimeOffDashboard: () async => _dashboard(pending: 2),
        timeOffRetryDelay: Duration.zero,
      );

      await provider.fetchTimeOffData(showLoader: false);

      expect(provider.timeOffBalances.map((b) => b.name), [
        'Paid Time Off',
        'Training Time Off',
      ]);
      expect(provider.pendingAllocationCount, 2);
      expect(provider.timeOffDataFailed, isFalse);
    });

    test('retries once, so a one-off failure still shows the cards', () async {
      var calls = 0;
      final provider = ManagerApprovalsProvider(
        readTimeOffDashboard: () async {
          calls++;
          if (calls == 1) throw Exception('session expired while renewing');
          return _dashboard();
        },
        timeOffRetryDelay: Duration.zero,
      );

      await provider.fetchTimeOffData(showLoader: false);

      expect(calls, 2);
      expect(provider.timeOffBalances, hasLength(2));
      expect(provider.timeOffDataFailed, isFalse);
    });

    test('a failed refresh keeps the cards already on screen', () async {
      var fail = false;
      final provider = ManagerApprovalsProvider(
        readTimeOffDashboard: () async {
          if (fail) throw Exception('server error');
          return _dashboard(pending: 3);
        },
        timeOffRetryDelay: Duration.zero,
      );
      await provider.fetchTimeOffData(showLoader: false);

      fail = true;
      await provider.fetchTimeOffData(showLoader: false);

      // Used to wipe them (and the pending count) on any error.
      expect(provider.timeOffBalances, hasLength(2));
      expect(provider.pendingAllocationCount, 3);
      expect(provider.timeOffDataFailed, isTrue);
    });

    test(
      'a first load that fails is flagged so the page can offer a retry',
      () async {
        final provider = ManagerApprovalsProvider(
          readTimeOffDashboard: () async => throw Exception('server error'),
          timeOffRetryDelay: Duration.zero,
        );

        await provider.fetchTimeOffData(showLoader: false);

        expect(provider.timeOffBalances, isEmpty);
        expect(provider.timeOffDataFailed, isTrue);
      },
    );

    test('retryTimeOffData recovers and clears the failed state', () async {
      var fail = true;
      final provider = ManagerApprovalsProvider(
        readTimeOffDashboard: () async {
          if (fail) throw Exception('server error');
          return _dashboard();
        },
        timeOffRetryDelay: Duration.zero,
      );
      await provider.fetchTimeOffData(showLoader: false);
      expect(provider.timeOffDataFailed, isTrue);

      fail = false;
      await provider.retryTimeOffData();

      expect(provider.timeOffDataFailed, isFalse);
      expect(provider.timeOffBalances, hasLength(2));
      expect(provider.isLoading, isFalse);
    });

    test('an older read finishing late cannot overwrite a newer one', () async {
      final slow = Completer<TimeOffDashboard>();
      var call = 0;
      final provider = ManagerApprovalsProvider(
        readTimeOffDashboard: () {
          call++;
          if (call == 1) return slow.future;
          return Future.value(_dashboard(pending: 5));
        },
        timeOffRetryDelay: Duration.zero,
      );

      final older = provider.fetchTimeOffData(showLoader: false);
      await provider.fetchTimeOffData(showLoader: false);
      expect(provider.pendingAllocationCount, 5);

      slow.complete(
        const TimeOffDashboard(balances: [], pendingAllocations: 0),
      );
      await older;

      expect(provider.pendingAllocationCount, 5);
      expect(provider.timeOffBalances, hasLength(2));
    });

    test('logout clears the cards and the failed state', () async {
      final provider = ManagerApprovalsProvider(
        readTimeOffDashboard: () async => throw Exception('server error'),
        timeOffRetryDelay: Duration.zero,
      );
      await provider.fetchTimeOffData(showLoader: false);

      provider.clearOnManagerLogout();

      expect(provider.timeOffBalances, isEmpty);
      expect(provider.timeOffDataFailed, isFalse);
    });
  });
}
