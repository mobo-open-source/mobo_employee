import 'package:flutter/material.dart';
import 'package:mobo_employees/core/const/all_design.dart';
import 'package:mobo_employees/features/employee/leave/provider/leave_page_provider.dart';
import 'package:mobo_employees/shared/widgets/calendar/leave_month_calendar.dart';
import 'package:provider/provider.dart';
import '../model/leaveMyCalender.dart';

/// The Leave page's My Calendar tab: the employee's own time off for the
/// month, drawn by the shared [LeaveMonthCalendar].
class MyLeaveCalender extends StatelessWidget {
  const MyLeaveCalender({super.key});

  /// The dot colour of a time off in [state].
  static Color eventColor(LeaveMyCalenderModel e) {
    switch (e.state) {
      case 'refuse':
        return AppColors.ColorF90000;
      case 'cancel':
        return Colors.transparent;

      // Still awaiting approval: "To Approve" and "Second Approval".
      case 'confirm' || 'validate1':
        return AppColors.colorFFAA00;

      case 'validate':
        return AppColors.color007AFF;

      default:
        return AppColors.greyShade500Color;
    }
  }

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<LeavePageProvider>();

    return LeaveMonthCalendar(
      month: provider.currentMonth,
      selectedDate: provider.selectedDate,
      marks: [
        for (final e in provider.calendarEvents)
          if (e.dateFrom != null && e.dateTo != null)
            LeaveCalendarMark(
              from: e.dateFrom!,
              to: e.dateTo!,
              color: eventColor(e),
            ),
      ],
      unusualDays: provider.unusualDays,
      onPreviousMonth: provider.goToPreviousMyMonth,
      onNextMonth: provider.goToNextMyMonth,
      onSelectDate: provider.selectDate,
    );
  }
}
