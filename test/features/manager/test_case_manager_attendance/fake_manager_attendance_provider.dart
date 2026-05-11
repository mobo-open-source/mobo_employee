import 'package:mobo_employees/features/manager/manager_attendance/model/model_manager_attendance_data.dart';
import 'package:mobo_employees/features/manager/manager_attendance/provider/manager_attendance_provider.dart';

class FakeManagerAttendanceProvider extends ManagerAttendanceProvider {
  bool isLoading = false;
  bool isRootedGroupsCalled = false;
  bool isFetchAllAttendance = false;

  FakeManagerAttendanceProvider({
    bool startLoading = false,
    bool startGroupingData = false,
  }) {
    isLoading = startLoading;
    isGroupLoading = startGroupingData;

    modelManagerAttendanceData = ModelManagerAttendanceData(
      attendanceLength: 2,
      attendanceRecords: [
        AttendanceRecord(
          employee: HandleOdooData(id: 001, name: "John"),
          id: 1,
          workedHours: 8.0,
          overtimeHours: 7.5,
          validatedOvertimeHours: 9.5,
          inLatitude: 2.5,
          inLongitude: 2.5,
          outLatitude: 2.5,
          outLongitude: 2.5,
          color: 1,
        ),
        AttendanceRecord(
          employee: HandleOdooData(id: 002, name: "Abraham"),
          id: 2,
          workedHours: 8.5,
          overtimeHours: 7.5,
          validatedOvertimeHours: 9.5,
          inLatitude: 2.5,
          inLongitude: 2.5,
          outLatitude: 2.5,
          outLongitude: 2.5,
          color: 2,
        ),
      ],
    );
  }

  @override
  Future<void> refreshPage() async {
    isLoading = true;
    notifyListeners();
  }

  @override
  Future<void> fetchRootGroups() async {
    isRootedGroupsCalled = true;
    notifyListeners();
  }

  @override
  Future<void> fetchAllAttendances({bool silent = false}) async {
    isFetchAllAttendance = true;
    notifyListeners();
  }
}
