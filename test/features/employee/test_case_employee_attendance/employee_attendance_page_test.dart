import 'package:flutter_test/flutter_test.dart';
import 'package:mobo_employees/features/employee/attendance/model/model_hr_employee_attendance.dart';
import 'fake_employee_attendance_provider.dart';

void main() {
  group("Attendance Provider Unit Test", () {
    test("Initial attendance data should be correct", () {
      final provider = FakeEmployeeAttendanceProvider();

      expect(provider.monthlyAttendanceCount, 20);
      expect(provider.monthlyLeaveCount, 2);
      expect(provider.attendancePercentage, 90);

      expect(provider.attendanceEmployeeModel?.name, "sampleName");
      expect(provider.attendanceEmployeeModel?.attendanceState, "checked_in");
      expect(provider.attendanceEmployeeModel?.hoursLastMonth, 160);
    });

    test("RefreshAttendance should update refreshCalled flag", () async {
      final provider = FakeEmployeeAttendanceProvider();
      expect(provider.refreshCalled, false);
      await provider.refreshAttendance(employeeId: 1, month: DateTime.now());
      expect(provider.refreshCalled, true);
    });

    test("Loading state when startLoading true", () {
      final provider = FakeEmployeeAttendanceProvider(startLoading: true);
      expect(provider.isLoading, true);
      expect(provider.isInitialLoaded, false);
    });

    test("Loading state when startLoading false", () {
      final provider = FakeEmployeeAttendanceProvider(startLoading: false);
      expect(provider.isLoading, false);
      expect(provider.isInitialLoaded, true);
    });

    test("AttendanceEmployeeModel should parse values correctly", () {
      final model = AttendanceEmployeeModel(
        id: 1,
        name: "Test Employee",
        isAbsent: false,
        attendanceState: "checked_out",
        hoursLastMonth: 120,
      );

      expect(model.name, "Test Employee");
      expect(model.isAbsent, false);
      expect(model.attendanceState, "checked_out");
      expect(model.hoursLastMonth, 120);
    });

    test("updateMonth should update selectedMonth", () {
      final provider = FakeEmployeeAttendanceProvider();
      final newMonth = DateTime(2025, 5);
      provider.updateMonth(newMonth);
      expect(provider.selectedMonth.year, 2025);
      expect(provider.selectedMonth.month, 5);
    });

    test("selectDay should update selectedDay and focusedDay", () {
      final provider = FakeEmployeeAttendanceProvider();
      final selected = DateTime(2024, 6, 10);
      final focused = DateTime(2024, 6, 1);
      provider.selectDay(selected, focused, 4);
      expect(provider.selectedDay, selected);
      expect(provider.focusedDay, focused);
    });

    test("isPresent should return true if attendance date exists", () {
      final provider = FakeEmployeeAttendanceProvider();
      final date = DateTime(2024, 6, 10);
      provider.attendanceDates.add(date);
      expect(provider.isPresent(date), true);
    });
    test("isLeave should return true when leave date exists", () {
      final provider = FakeEmployeeAttendanceProvider();
      final date = DateTime(2024, 6, 12);
      provider.leaveDates.add(date);
      expect(provider.isLeave(date), true);
    });

    test("isHoliday should return true when holiday exists", () {
      final provider = FakeEmployeeAttendanceProvider();
      final date = DateTime(2024, 6, 15);
      provider.holidayDates.add(date);
      expect(provider.isHoliday(date), true);
    });

    test("isUnusual should return true when unusual date exists", () {
      final provider = FakeEmployeeAttendanceProvider();
      final date = DateTime(2024, 6, 20);
      provider.unusualDates.add(date);
      expect(provider.isUnusual(date), true);
    });

    test("ClearOnLogout should reset attendance data", () {
      final provider = FakeEmployeeAttendanceProvider();
      provider.clearOnLogout();
      expect(provider.attendanceEmployeeModel, null);
      expect(provider.monthlyAttendanceCount, 0);
      expect(provider.monthlyLeaveCount, 0);
      expect(provider.attendancePercentage, 0);
    });

    test("hoursToHHMM conversion should be correct", () {
      final provider = FakeEmployeeAttendanceProvider();
      final result = provider.hoursToHHMM(7.5);
      expect(result, "07:30");
    });

    test("Working days calculation should be correct", () {
      final provider = FakeEmployeeAttendanceProvider();
      final days = provider.daysPresent;
      expect(days, 0);
    });
  });
}
