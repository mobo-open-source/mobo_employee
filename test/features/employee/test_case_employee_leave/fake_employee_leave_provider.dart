import 'package:mobo_employees/features/employee/leave/model/leaveMyCalender.dart';
import 'package:mobo_employees/features/employee/leave/model/model_time_off_type.dart';
import 'package:mobo_employees/features/employee/leave/provider/leave_page_provider.dart';
import 'package:mobo_employees/features/manager/manager_approvals/models/model_timeoff_data.dart';

class FakeEmployeeLeaveProvider extends LeavePageProvider {
  bool saveCalled = false;

  FakeEmployeeLeaveProvider() {
    calendarEvents.addAll([
      LeaveMyCalenderModel(
        id: 1,
        description: "Casual Leave Description",
        leaveTypeName: "Casual Leave",
        dateFrom: DateTime(2026, 3, 10),
        dateTo: DateTime(2026, 3, 10),
        dateFromFormatted: "10 Mar 2026",
        dateToFormatted: "10 Mar 2026",
        state: "validate",
      ),
      LeaveMyCalenderModel(
        id: 2,
        description: "Sick Leave Description",
        leaveTypeName: "Sick Leave",
        dateFrom: DateTime(2026, 3, 15),
        dateTo: DateTime(2026, 3, 15),
        dateFromFormatted: "15 Mar 2026",
        dateToFormatted: "15 Mar 2026",
        state: "confirm",
      ),
      LeaveMyCalenderModel(
        id: 3,
        description: "Casual Leave Description",
        leaveTypeName: "Casual Leave",
        dateFrom: DateTime(2026, 3, 10),
        dateTo: DateTime(2026, 3, 10),
        dateFromFormatted: "10 Mar 2026",
        dateToFormatted: "10 Mar 2026",
        state: "validate",
      ),
    ]);

    timeOffList.addAll([
      ModelTimeOffData(
        id: 1,
        employeeId: 10,
        userId: 20,
        employeeName: "Akshay",
        departmentId: 1,
        departmentName: "Development",
        description: "Vacation",
        leaveTypeName: "Casual Leave",
        durationDisplay: "1 Day",
        dateFrom: DateTime(2026, 3, 10),
        dateTo: DateTime(2026, 3, 10),
        dateFromFormatted: "Mar 10",
        dateToFormatted: "Mar 10, 2026",
        state: "confirm",
        canApprove: true,
        canValidate: true,
        canRefuse: true,
        create_date: "Mar 10, 2026",
      ),
    ]);

    modelTimeOffType = ModelTimeOffType(
      id: 1,
      displayName: "Casual Leave",
      requiresAllocation: false,
      employeeRequests: true,
      responsibleIds: [],
      responsibleNames: [],
    );
  }

  @override
  Future<void> fetchLeaveMyCalendarEventsFunction({
    bool showLoader = true,
  }) async {
    notifyListeners();
  }

  @override
  Future<String?> saveLeave() async {
    saveCalled = true;
    notifyListeners();
    return null;
  }

  @override
  Future<void> fetchMyTimeOff({bool isRefresh = false}) async {
    /// prevent API call
    notifyListeners();
  }
}
