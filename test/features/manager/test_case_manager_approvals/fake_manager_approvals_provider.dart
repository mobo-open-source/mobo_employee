import 'package:mobo_employees/features/manager/manager_approvals/models/model_leave_calendar_event.dart';
import 'package:mobo_employees/features/manager/manager_approvals/models/model_timeoff_data.dart';
import 'package:mobo_employees/features/manager/manager_approvals/providers/manager_approvals_provider.dart';

class FakeManagerApprovalsProvider extends ManagerApprovalsProvider {
  bool fakeLoading = false;
  FakeManagerApprovalsProvider() {
    calendarEvents.addAll([
      LeaveCalendarEvent(
        id: 1,
        description: "Casual Leave Description",
        leaveTypeName: "Casual Leave",
        dateFrom: DateTime(2026, 3, 10),
        dateTo: DateTime(2026, 3, 10),
        dateFromFormatted: "10 Mar 2026",
        dateToFormatted: "10 Mar 2026",
        state: "validate",
        durationDisplay: "1 Day",
      ),
      LeaveCalendarEvent(
        id: 2,
        description: "Sick Leave Description",
        leaveTypeName: "Sick Leave",
        dateFrom: DateTime(2026, 3, 15),
        dateTo: DateTime(2026, 3, 15),
        dateFromFormatted: "15 Mar 2026",
        dateToFormatted: "15 Mar 2026",
        state: "confirm",
        durationDisplay: "3 Days",
      ),
      LeaveCalendarEvent(
        id: 3,
        description: "Casual Leave Description",
        leaveTypeName: "Casual Leave",
        dateFrom: DateTime(2026, 3, 10),
        dateTo: DateTime(2026, 3, 10),
        dateFromFormatted: "10 Mar 2026",
        dateToFormatted: "10 Mar 2026",
        state: "validate",
        durationDisplay: "1 Day",
      ),
    ]);

    timeOffList.addAll([
      ModelTimeOffData(
        id: 1,
        employeeId: 10,
        userId: 20,
        employeeName: "Employee1",
        departmentId: 1,
        departmentName: "Development",
        description: "Description",
        leaveTypeName: "Casual Leave",
        durationDisplay: "1 Day",
        dateFrom: DateTime(2026, 3, 15),
        dateTo: DateTime(2026, 3, 15),
        dateFromFormatted: "Mar 15",
        dateToFormatted: "15, 2026",
        state: "confirm",
        canApprove: true,
        canValidate: true,
        canRefuse: true,
        create_date: "Mar 10, 2026",
      ),
    ]);
  }
  @override
  Future<void> fetchTimeOffDetails() async {
    fakeLoading = true;
    notifyListeners();
  }

  @override
  Future<void> fetchLeaveCalendarEventsFunction({
    bool showLoader = true,
  }) async {
    fakeLoading = true;
    notifyListeners();
  }
}
