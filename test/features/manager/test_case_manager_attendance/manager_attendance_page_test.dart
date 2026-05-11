import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mobo_employees/features/manager/manager_attendance/provider/manager_attendance_provider.dart';

import 'fake_manager_attendance_provider.dart';

void main() {
  group("Manager Attendance Page Unit Test", () {
    final provider = FakeManagerAttendanceProvider();
    final modelAttendanceRecords =
        provider.modelManagerAttendanceData?.attendanceRecords;

    test("Initial Attendance Records Data", () {
      expect(provider.modelManagerAttendanceData?.attendanceLength, 2);
      expect(modelAttendanceRecords?.first.id, 1);
      expect(modelAttendanceRecords?.first.employee?.id, 001);
      expect(modelAttendanceRecords?.first.employee?.name, "John");
    });

    test("Check RefreshPage Calling check", () {
      expect(provider.isLoading, false);
      provider.refreshPage();
      expect(provider.isLoading, true);
    });

    test("Check Groups Calling Check", () {
      expect(provider.isRootedGroupsCalled, false);
      provider.fetchRootGroups();
      expect(provider.isRootedGroupsCalled, true);
    });

    test("Fetch All Attendance", () {
      expect(provider.isFetchAllAttendance, false);
      provider.fetchAllAttendances();
      expect(provider.isFetchAllAttendance, true);
    });

    test("Check GroupBy add/remove", () {
      provider.toggleDraftGroupBy(AttendanceGroupBy.month);
      provider.toggleDraftGroupBy(AttendanceGroupBy.employee);

      expect(provider.draftGroupBy.contains(AttendanceGroupBy.month), true);
      provider.toggleDraftGroupBy(AttendanceGroupBy.month);
      provider.toggleDraftGroupBy(AttendanceGroupBy.employee);
      expect(provider.draftGroupBy.contains(AttendanceGroupBy.month), false);
      expect(provider.draftGroupBy.contains(AttendanceGroupBy.employee), false);
    });

    test("Check ClearSearch in TextFormField", () {
      provider.searchController.text = "John";
      provider.clearSearch();
      expect(provider.searchController.text, "");
      expect(provider.currentSearch, "");
    });

    test("Formatting the time", () {
      final time = DateTime(2026, 03, 11, 10, 33);
      final formattedTime = provider.formatTimeAMPM(time);
      expect(
        formattedTime.contains("AM") || formattedTime.contains("PM"),
        true,
      );
    });

    test("Format the working Hours", () {
      final formattedWorkingHours = provider.formatWorkedHours(8.5);
      expect(formattedWorkingHours, "08:30");
    });

    test("Active Filter Count", () {
      provider.toggleDraftGroupBy(AttendanceGroupBy.month);
      provider.toggleDraftGroupBy(AttendanceGroupBy.employee);
      expect(provider.draftGroupBy.length, 2);
      provider.applyDraftFilters();
      expect(provider.activeFilterCount, 2);
    });

    test("Check the clear on Logout", () {
      provider.searchController.text = "abcdef";
      provider.currentSearch = "abcdef";
      provider.clearOnManagerLogout();
      expect(provider.searchController.text, "");
      expect(provider.currentSearch, "");
    });

    test("Pagination Working", () {
      provider.groupBy.clear();
      provider.totalAttendanceCount = 100;
      provider.loadNextPage();
      expect(provider.isFetchAllAttendance, true);
      provider.loadNextPage();
      expect(provider.isFetchAllAttendance, true);
      provider.loadPrevPage();
      expect(provider.isFetchAllAttendance, true);
    });

    test("Reset Filters", () {
      provider.draftGroupBy.add(AttendanceGroupBy.employee);
      provider.draftGroupBy.add(AttendanceGroupBy.month);
      provider.resetDraftFilters();
      expect(provider.draftGroupBy.isEmpty, true);
    });

    test("Can Go Next & Previous Page", () {
      provider.groupBy.clear();
      provider.totalAttendanceCount = 100;
      expect(provider.canGoNext, true);
      provider.loadNextPage();
      expect(provider.canGoPrev, true);
    });
  });
}
