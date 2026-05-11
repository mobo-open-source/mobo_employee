import 'package:mobo_employees/features/employee/dashboard/model/model_dashboard_data.dart';
import 'package:mobo_employees/features/employee/dashboard/provider/dashboard_provider.dart';

class FakeEmployeeDashboardProvider extends DashboardProvider {
  bool refreshCalled = false;

  FakeEmployeeDashboardProvider({bool startLoading = false}) {
    isDashboardLoading = startLoading;
    isDashboardNewDataLoading = !startLoading;

    userName = "Akshay";

    dashboard = DashboardModel(
      userName: "Akshay",
      greetings: "Morning",
      isCheckedIn: true,
      currentTime: "09:30 AM",
      isCheckInOutLoading: false,
      leaveBalance: 10,
      leaveRequestCount: 3,
      yesterdayWorkingHours: 7.5,
      nextLeaveDate: "Jun 20",
      recentLeave: null,
      isLoading: false,
      userImageBytes: null,
    );
  }

  @override
  Future<void> refreshDashboard({bool isRefresh = false}) async {
    refreshCalled = true;
    notifyListeners();
  }
}
