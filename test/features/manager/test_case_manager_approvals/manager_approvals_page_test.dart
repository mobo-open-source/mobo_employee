import 'package:flutter_test/flutter_test.dart';

import 'fake_manager_approvals_provider.dart';

void main() {
  group("Manager Approvals Page Unit Test", () {
    final provider = FakeManagerApprovalsProvider();

    test("Change Tab index", () {
      expect(provider.selectedTabIndex, 0);
      provider.setTab(1);
      expect(provider.selectedTabIndex, 1);
    });

    test("Initial Calender Events", () {
      expect(provider.calendarEvents.length, 3);
      expect(
        provider.calendarEvents.first.description,
        "Casual Leave Description",
      );
      expect(provider.calendarEvents.first.state, "validate");
    });

    test("Select Date", () {
      final date = DateTime(2026, 3, 10);
      provider.selectDate(date);
      expect(provider.selectedDate, date);
    });

    test("Selected Event Date", () {
      provider.selectDate(DateTime(2026, 03, 10));
      final events = provider.selectedDateEvents;
      expect(events.length, 2);
      expect(events.first.description, "Casual Leave Description");
    });

    test("Go to Next month", () {
      final currentMonth = provider.currentMonth;
      provider.goToNextMonth();
      expect(provider.currentMonth.month, currentMonth.month + 1);
      final anotherCurrentMonth = provider.currentMonth;
      provider.goToPreviousMonth();
      expect(provider.currentMonth.month, anotherCurrentMonth.month - 1);
    });

    test("Go to Previous month", () {
      final anotherCurrentMonth = provider.currentMonth;
      provider.goToPreviousMonth();
      expect(provider.currentMonth.month, anotherCurrentMonth.month - 1);
    });

    test("Initial TimeOff List", () {
      expect(provider.timeOffList.length, 1);
      expect(provider.timeOffList.first.employeeName, "Employee1");
      expect(provider.timeOffList.first.leaveTypeName, "Casual Leave");
    });

    test("Validate TimeOff State Tracking", () async {
      provider.validateTimeOff(1, "confirm");
      expect(provider.isValidating(1), true);
    });

    test("Refuse TimeOff State Tracking", () async {
      provider.refuseTimeOff(1);
      expect(provider.isRefusing(1), true);
    });

    test("Clear On Manager Logout", () {
      provider.selectDate(DateTime(2026, 3, 10));
      provider.clearOnManagerLogout();
      expect(provider.calendarEvents.isEmpty, true);
      expect(provider.timeOffList.isEmpty, true);
      expect(provider.selectedDate, null);
    });
  });
}
