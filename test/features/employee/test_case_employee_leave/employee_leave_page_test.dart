import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';

import 'fake_employee_leave_provider.dart';

void main() {
  group("Employee Leave Page Unit Test Case", () {
    test("Change Tab Index", () {
      final provider = FakeEmployeeLeaveProvider();
      expect(provider.selectedTabIndex, 0);
      provider.setTab(1);
      expect(provider.selectedTabIndex, 1);
    });

    test("Initial Calendar Events", () {
      final provider = FakeEmployeeLeaveProvider();
      expect(provider.calendarEvents.length, 3);
      expect(
        provider.calendarEvents.first.description,
        "Casual Leave Description",
      );
      expect(provider.calendarEvents.first.state, "validate");
    });

    test("Select Calendar Date", () {
      final provider = FakeEmployeeLeaveProvider();
      final date = DateTime(2026, 3, 10);
      provider.selectDate(date);
      expect(provider.selectedDate, date);
    });

    test("Selected Date Events", () {
      final provider = FakeEmployeeLeaveProvider();
      provider.selectDate(DateTime(2026, 3, 10));
      final events = provider.selectedDateEvents;
      expect(events.length, 2);
      expect(events.first.description, "Casual Leave Description");
    });

    test("Go To Next Month", () {
      final provider = FakeEmployeeLeaveProvider();
      final currentMonth = provider.currentMonth;
      provider.goToNextMyMonth();
      expect(provider.currentMonth.month, currentMonth.month + 1);
    });

    test("Go To Previous Month", () {
      final provider = FakeEmployeeLeaveProvider();
      final currentMonth = provider.currentMonth;
      provider.goToPreviousMyMonth();
      expect(provider.currentMonth.month, currentMonth.month - 1);
    });

    test("Initial TimeOff List", () {
      final provider = FakeEmployeeLeaveProvider();
      expect(provider.timeOffList.length, 1);
      expect(provider.timeOffList.first.employeeName, "Akshay");
      expect(provider.timeOffList.first.leaveTypeName, "Casual Leave");
    });

    test("Submit Button Enabled Logic", () {
      final provider = FakeEmployeeLeaveProvider();
      provider.leaveTypeController.text = "Casual Leave";
      provider.fromDateController.text = "Mar 10";
      provider.toDateController.text = "Mar 11";
      expect(provider.isSubmitEnabled, true);
    });

    test("Submit Button Disabled When Fields Empty", () {
      final provider = FakeEmployeeLeaveProvider();
      provider.leaveTypeController.clear();
      provider.fromDateController.clear();
      provider.toDateController.clear();
      expect(provider.isSubmitEnabled, false);
    });

    test("SpeedDial should appear only when tab index is 1", () {
      final provider = FakeEmployeeLeaveProvider();
      expect(provider.selectedTabIndex, 0);
      bool showSpeedDial = provider.selectedTabIndex == 1;
      expect(showSpeedDial, false);
      provider.setTab(1);
      showSpeedDial = provider.selectedTabIndex == 1;
      expect(showSpeedDial, true);
    });

    test("Apply Leave Save Trigger", () async {
      final provider = FakeEmployeeLeaveProvider();
      provider.leaveTypeController.text = "Casual Leave";
      provider.fromDateController.text = "Mar 10";
      provider.toDateController.text = "Mar 11";
      final error = await provider.saveLeave();
      expect(error, null);
      expect(provider.saveCalled, true);
    });

    test("Clear Form Reset Fields", () {
      final provider = FakeEmployeeLeaveProvider();
      provider.leaveTypeController.text = "Leave";
      provider.fromDateController.text = "Mar 10";
      provider.toDateController.text = "Mar 11";
      provider.descriptionController.text = "Vacation";
      provider.clearForm();
      expect(provider.leaveTypeController.text, "");
      expect(provider.fromDateController.text, "");
      expect(provider.toDateController.text, "");
      expect(provider.descriptionController.text, "");
    });

    test("Remove File Reset Attachment", () {
      final provider = FakeEmployeeLeaveProvider();
      provider.removeFile();
      expect(provider.attachedFile, null);
      expect(provider.attachedFileName, null);
    });

    test("Clear On Logout", () {
      final provider = FakeEmployeeLeaveProvider();
      provider.selectDate(DateTime(2026, 3, 10));
      provider.clearOnLogout();
      expect(provider.timeOffList.isEmpty, true);
    });
  });
}
