import 'package:flutter/material.dart';
import 'package:mobo_employees/core/const/all_design.dart';
import 'package:mobo_employees/features/manager/manager_approvals/providers/manager_approvals_provider.dart';
import 'package:mobo_employees/shared/widgets/calendar/leave_month_calendar.dart';
import 'package:provider/provider.dart';

/// The Approvals page's Calendar tab: every employee's time off for the month,
/// drawn by the shared [LeaveMonthCalendar].
class WidgetLeaveCalendar extends StatelessWidget {
  const WidgetLeaveCalendar({super.key});

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<ManagerApprovalsProvider>();

    return LeaveMonthCalendar(
      month: provider.currentMonth,
      selectedDate: provider.selectedDate,
      marks: [
        for (final e in provider.calendarEvents)
          if (e.dateFrom != null && e.dateTo != null)
            LeaveCalendarMark(
              from: e.dateFrom!,
              to: e.dateTo!,
              color: eventColor(e.state),
            ),
      ],
      unusualDays: provider.unusualDays,
      onPreviousMonth: provider.goToPreviousMonth,
      onNextMonth: provider.goToNextMonth,
      onSelectDate: provider.selectDate,
    );
  }

  /// ───── Helpers ─────

  /// Legend color of a time off in [state] (Odoo `hr.leave.state`).
  static Color eventColor(String state) {
    switch (state) {
      case 'refuse':
      case 'cancel':
        return AppColors.ColorF90000;
      case 'confirm':
      case 'validate1':
        return AppColors.colorFFAA00;
      case 'validate':
        return AppColors.color007AFF;
      default:
        return AppColors.greyShade500Color;
    }
  }
}
