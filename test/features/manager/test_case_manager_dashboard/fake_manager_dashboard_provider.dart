import 'package:mobo_employees/features/manager/manager_dashboard/model/model_manager_dashboard.dart';
import 'package:mobo_employees/features/manager/manager_dashboard/provider/manager_dashboard_provider.dart';

class FakeManagerDashboardProvider extends ManagerDashboardProvider {
  bool refreshCalled = false;

  FakeManagerDashboardProvider({bool startLoading = false}) {
    isManagerDashboardLoading = startLoading;
    isManagerDashboardDataLoading = !startLoading;

    dashboard = ModelManagerDashboard(
      user: ManagerUserModel(
        employeeId: 1,
        name: "John",
        profileImage: null,
        greetings: "Morning",
      ),
      overview: ManagerOverviewModel(
        totalEmployees: 25,
        todayAttendance: 18,
        todayLeaves: 3,
        leaveRequests: 2,
      ),
      todayReport: ManagerTodayReportModel(
        lateCheckIns: 5,
        payslipsGenerated: 0,
        newLeaveRequestsForToday: 4,
      ),
    );
  }

  @override
  Future<void> refreshDashboard({bool isRefresh = false}) async {
    refreshCalled = true;
    notifyListeners();
  }
}
