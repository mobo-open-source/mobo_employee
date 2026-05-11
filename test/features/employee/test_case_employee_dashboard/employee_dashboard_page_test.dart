import 'package:flutter_test/flutter_test.dart';
import 'package:mobo_employees/features/employee/dashboard/model/model_dashboard_data.dart';
import 'fake_employee_dashboard_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  group("Employees Dashboard Unit Test", () {
    test("Initial dashboard data should be correct", () {
      final provider = FakeEmployeeDashboardProvider();

      expect(provider.dashboard.userName, "Akshay");
      expect(provider.dashboard.greetings, "Morning");

      expect(provider.dashboard.leaveBalance, 10);
      expect(provider.dashboard.leaveRequestCount, 3);
      expect(provider.dashboard.yesterdayWorkingHours, 7.5);

      expect(provider.dashboard.isCheckedIn, true);
      expect(provider.dashboard.currentTime, "09:30 AM");
    });

    test("RefreshDashboard should update refreshCalled flag", () async {
      final provider = FakeEmployeeDashboardProvider();
      expect(provider.refreshCalled, false);
      await provider.refreshDashboard();
      expect(provider.refreshCalled, true);
    });

    test("Loading state when startLoading true", () {
      final provider = FakeEmployeeDashboardProvider(startLoading: true);
      expect(provider.isDashboardLoading, true);
      expect(provider.isDashboardNewDataLoading, false);
    });

    test("Loading state when startLoading false", () {
      final provider = FakeEmployeeDashboardProvider(startLoading: false);
      expect(provider.isDashboardLoading, false);
      expect(provider.isDashboardNewDataLoading, true);
    });

    test("Check DashboardModel initial empty data", () {
      final model = DashboardModel.initial();
      expect(model.userName, "-");
      expect(model.leaveBalance, 0);
      expect(model.leaveRequestCount, 0);
      expect(model.yesterdayWorkingHours, 0);
      expect(model.recentLeave, null);
    });

    test("Greetings check", () {
      final provider = FakeEmployeeDashboardProvider();
      provider.setGreetings();
      expect(
        ["Morning", "Afternoon", "Evening"].contains(provider.greetings),
        true,
      );
    });

    test("Check clear data on logout", () async {
      SharedPreferences.setMockInitialValues({});
      final provider = FakeEmployeeDashboardProvider();
      provider.userName = "Test User";
      provider.leaveBalance = 20;
      provider.leaveRequestCount = 5;
      await provider.clearOnLogout();
      expect(provider.userName, "-");
      expect(provider.leaveBalance, 0);
      expect(provider.leaveRequestCount, 0);
      expect(provider.recentLeave, null);
    });

    test("clearDashboard should reset user data", () {
      final provider = FakeEmployeeDashboardProvider();
      provider.userName = "Sample User";
      provider.greetings = "Morning";
      provider.clearDashboard();
      expect(provider.userName, "-");
      expect(provider.greetings, "");
      expect(provider.isDashboardNewDataLoading, false);
    });
  });
}
