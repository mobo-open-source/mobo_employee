import 'package:flutter_test/flutter_test.dart';
import 'package:mobo_employees/features/manager/manager_attendance/provider/manager_attendance_provider.dart';
import 'package:mobo_employees/features/manager/manager_employees/provider/manager_employees_provider.dart';

/// The manager view shows what Odoo's record rules let the user read, so the
/// lists add no "direct reports only" scope of their own; the "My Team" chip
/// is what narrows to direct reports.
void main() {
  group('ManagerAttendanceProvider.baseDomain', () {
    test('adds no scope of its own', () {
      final provider = ManagerAttendanceProvider()..currentUserId = 6;

      expect(provider.baseDomain, [
        ['employee_id.active', '=', true],
      ]);
    });

    test('"My Team" narrows to direct reports', () {
      final provider = ManagerAttendanceProvider()
        ..currentUserId = 6
        ..activeFilters = {AttendanceFilter.myTeam};

      expect(provider.baseDomain, [
        '&',
        ['employee_id.active', '=', true],
        ['employee_id.parent_id.user_id', '=', 6],
      ]);
    });
  });

  group('ManagerEmployeesProvider.buildDomain', () {
    setUp(() => ManagerEmployeesProvider.currentUserId = 6);
    tearDown(() => ManagerEmployeesProvider.currentUserId = null);

    test('adds no scope of its own', () {
      expect(ManagerEmployeesProvider().buildDomain(), isEmpty);
    });

    test('"My Team" narrows to direct reports', () {
      final provider = ManagerEmployeesProvider()
        ..activeFilters = {EmployeeFilter.myTeam};

      expect(provider.buildDomain(), [
        ['parent_id.user_id', '=', 6],
      ]);
    });
  });
}
