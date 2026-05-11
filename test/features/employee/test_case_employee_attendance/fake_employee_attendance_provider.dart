import 'package:mobo_employees/features/employee/attendance/model/model_hr_employee_attendance.dart';
import 'package:mobo_employees/features/employee/attendance/provider/attendance_provider.dart';

class FakeEmployeeAttendanceProvider extends AttendanceProvider {
  bool refreshCalled = false;

  int fakeAttendanceCount = 20;
  int fakeLeaveCount = 2;
  double fakeAttendancePercentage = 90;

  FakeEmployeeAttendanceProvider({bool startLoading = false}) {
    isInitialLoaded = !startLoading;
    isLoading = startLoading;

    attendanceEmployeeModel = AttendanceEmployeeModel(
      id: 1,
      name: "sampleName",
      isAbsent: false,
      attendanceState: "checked_in",
      hoursLastMonth: 160,
      resourceCalendarId: 1,
      resourceCalendarName: "General",
    );
  }

  @override
  int get monthlyAttendanceCount => fakeAttendanceCount;

  @override
  int get monthlyLeaveCount => fakeLeaveCount;

  @override
  double get attendancePercentage => fakeAttendancePercentage;

  @override
  Future<void> refreshAttendance({
    required int employeeId,
    required DateTime month,
  }) async {
    refreshCalled = true;
    notifyListeners();
  }

  @override
  void clearOnLogout() {
    attendanceEmployeeModel = null;
    fakeAttendanceCount = 0;
    fakeLeaveCount = 0;
    fakeAttendancePercentage = 0;
    super.clearOnLogout();
  }
}
