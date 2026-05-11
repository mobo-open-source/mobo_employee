import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mobo_employees/features/manager/manager_dashboard/model/model_manager_dashboard.dart';
import 'fake_manager_dashboard_provider.dart';

void main() {
  group("Manager Dashboard Page Unit Test", () {
    test("Initial dashboard data should be correct", () {
      final provider = FakeManagerDashboardProvider();

      expect(provider.dashboard.user.name, "John");
      expect(provider.dashboard.user.employeeId, 1);

      expect(provider.dashboard.overview.totalEmployees, 25);
      expect(provider.dashboard.overview.todayAttendance, 18);
      expect(provider.dashboard.overview.todayLeaves, 3);
      expect(provider.dashboard.overview.leaveRequests, 2);

      expect(provider.dashboard.todayReport.lateCheckIns, 5);
      expect(provider.dashboard.todayReport.payslipsGenerated, 0);
      expect(provider.dashboard.todayReport.newLeaveRequestsForToday, 4);
    });

    test("RefreshDashboard should update refreshCalled flag", () async {
      final provider = FakeManagerDashboardProvider();
      expect(provider.refreshCalled, false);
      await provider.refreshDashboard();
      expect(provider.refreshCalled, true);
    });

    test("Loading state when startLoading true", () {
      final provider = FakeManagerDashboardProvider(startLoading: true);
      expect(provider.isManagerDashboardLoading, true);
      expect(provider.isManagerDashboardDataLoading, false);
    });

    test("Loading state when startLoading false", () {
      final provider = FakeManagerDashboardProvider(startLoading: false);
      expect(provider.isManagerDashboardLoading, false);
      expect(provider.isManagerDashboardDataLoading, true);
    });

    test("Check model Empty Data", () {
      final dashboardModel = ModelManagerDashboard.empty();
      expect(dashboardModel.user.name, "");
      expect(dashboardModel.overview.totalEmployees, 0);
      expect(dashboardModel.todayReport.lateCheckIns, 0);
    });

    test("Greetings check", () {
      final provider = FakeManagerDashboardProvider();
      provider.setGreetings();
      expect(
        ["Morning", "Evening", "Afternoon"].contains(provider.greetings),
        true,
      );
    });

    test("Check clear Data on logout", () {
      final provider = FakeManagerDashboardProvider();

      provider.userName = "Sample name";

      provider.totalLeaveRequests = 20;

      provider.totalTodayLeaves = 30;

      provider.clearOnManagerLogout();

      expect(provider.userName, "");

      expect(provider.totalLeaveRequests, 0);

      expect(provider.totalTodayLeaves, 0);
    });
  });
}
