import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import 'package:mobo_employees/core/const/app_colors.dart';
import 'package:mobo_employees/core/const/all_design.dart';
import 'package:mobo_employees/features/employee/leave/provider/leave_page_provider.dart';
import 'package:mobo_employees/features/manager/manager_approvals/models/model_leave_calendar_event.dart';
import 'package:provider/provider.dart';
import '../model/leaveMyCalender.dart';

class MyLeaveCalender extends StatelessWidget {
  const MyLeaveCalender({super.key});

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<LeavePageProvider>();
    final currentMonth = provider.currentMonth;

    final days = const ["SUN", "MON", "TUE", "WED", "THU", "FRI", "SAT"];
    final monthLabel = DateFormat.yMMMM().format(currentMonth);

    final events = provider.calendarEvents;

    final firstDayOfMonth = DateTime(currentMonth.year, currentMonth.month, 1);

    final daysInMonth = DateTime(
      currentMonth.year,
      currentMonth.month + 1,
      0,
    ).day;

    /// Sunday based index
    final startWeekday = firstDayOfMonth.weekday % 7;

    final totalCells = startWeekday + daysInMonth;

    List<LeaveMyCalenderModel> eventsForDate(
      DateTime date,
      List<LeaveMyCalenderModel> events,
    ) {
      final normalized = DateTime(date.year, date.month, date.day);

      return events.where((e) {
        if (e.dateFrom == null || e.dateTo == null) return false;

        final from = DateTime(
          e.dateFrom!.year,
          e.dateFrom!.month,
          e.dateFrom!.day,
        );

        final to = DateTime(e.dateTo!.year, e.dateTo!.month, e.dateTo!.day);

        return !normalized.isBefore(from) && !normalized.isAfter(to);
      }).toList();
    }

    const double kCellHeight = 70;
    const double kDateHeight = 28;

    return Container(
      padding: const EdgeInsets.symmetric(vertical: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.colorEDEDEB),
      ),
      child: Column(
        children: [
          /// HEADER
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12),
            child: Row(
              children: [
                _navButton(
                  icon: Icons.chevron_left,
                  onTap: provider.goToPreviousMyMonth,
                ),

                const SizedBox(width: 10),

                Expanded(
                  child: Container(
                    padding: const EdgeInsets.symmetric(vertical: 13),
                    decoration: BoxDecoration(
                      color: AppColors.colorF3F3F5,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(
                      monthLabel,
                      textAlign: TextAlign.center,
                      style: GoogleFonts.poppins(
                        fontSize: 13,
                        fontWeight: FontWeight.w400,
                        color: AppColors.color000000,
                      ),
                    ),
                  ),
                ),

                const SizedBox(width: 10),

                _navButton(
                  icon: Icons.chevron_right,
                  onTap: provider.goToNextMyMonth,
                ),
              ],
            ),
          ),

          const SizedBox(height: 10),

          /// LEGEND
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              _legendDot(AppColors.color007AFF, "Validated"),
              const SizedBox(width: 20),
              _legendDot(AppColors.colorFFAA00, "To Approve"),
              const SizedBox(width: 20),
              _legendDot(AppColors.ColorF90000, "Refused"),
            ],
          ),

          const SizedBox(height: 12),

          /// WEEK HEADER
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(color: AppColors.colorF8F9FA),
            child: Row(
              children: days
                  .map(
                    (d) => Expanded(
                      child: Center(
                        child: Text(
                          d,
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w600,
                            color: AppColors.color6A7282,
                          ),
                        ),
                      ),
                    ),
                  )
                  .toList(),
            ),
          ),

          const SizedBox(height: 8),

          /// CALENDAR GRID
          GridView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: totalCells,
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 7,
              crossAxisSpacing: 6,
              mainAxisExtent: 70,
            ),
            itemBuilder: (context, index) {
              if (index < startWeekday) {
                return const SizedBox.shrink();
              }

              final DateTime today = DateTime.now();

              bool isToday(DateTime d) {
                return d.year == today.year &&
                    d.month == today.month &&
                    d.day == today.day;
              }

              final day = index - startWeekday + 1;

              final date = DateTime(currentMonth.year, currentMonth.month, day);

              final normalizedDate = DateTime(date.year, date.month, date.day);

              final isSelected =
                  provider.selectedDate != null &&
                  provider.selectedDate!.year == normalizedDate.year &&
                  provider.selectedDate!.month == normalizedDate.month &&
                  provider.selectedDate!.day == normalizedDate.day;
              int _weekdayIndex(DateTime d) => d.weekday % 7;
              final eventsForDay = eventsForDate(
                normalizedDate,
                provider.calendarEvents,
              );

              DateTime _stripTime(DateTime d) =>
                  DateTime(d.year, d.month, d.day);
              final isUnusual = provider.unusualDays[normalizedDate] == true;

              Color eventColor(LeaveMyCalenderModel e) {
                switch (e.state) {
                  case 'refuse':
                    return AppColors.ColorF90000;
                  case 'cancel':
                    return Colors.transparent;

                  case 'confirm':
                    return AppColors.colorFFAA00;

                  case 'validate' || 'validate1':
                    return AppColors.color007AFF;

                  default:
                    return AppColors.greyShade500Color;
                }
              }

              return GestureDetector(
                onTap: () {
                  provider.selectDate(normalizedDate);
                },

                child: SizedBox(
                  height: kCellHeight,
                  child: Column(
                    children: [
                      /// DATE
                      SizedBox(
                        height: kDateHeight,
                        child: Center(
                          child: Container(
                            width: 28,
                            height: 28,
                            decoration: BoxDecoration(
                              color: isSelected
                                  ? primaryColor.withAlpha(80)
                                  : Colors.transparent,
                              border: Border.all(
                                color: isToday(normalizedDate)
                                    ? AppColors.color007AFF
                                    : Colors.transparent,
                                width: 2,
                              ),
                              shape: BoxShape.circle,
                            ),
                            alignment: Alignment.center,
                            child: Text(
                              "$day",
                              style: GoogleFonts.manrope(
                                fontSize: 16,
                                fontWeight: FontWeight.w600,
                                color: isSelected
                                    ? primaryColor
                                    : isToday(normalizedDate)
                                    ? AppColors.blackColor
                                    : isUnusual
                                    ? AppColors.greyShade500Color
                                    : AppColors.blackColor,
                              ),
                            ),
                          ),
                        ),
                      ),

                      /// EVENT DOTS
                      Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: eventsForDay.take(3).map((e) {
                          return Container(
                            margin: const EdgeInsets.symmetric(horizontal: 2),
                            width: 6,
                            height: 6,
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              color: eventColor(e),
                            ),
                          );
                        }).toList(),
                      ),

                      if (eventsForDay.length > 3)
                        Padding(
                          padding: const EdgeInsets.only(top: 2),
                          child: Text(
                            "+${eventsForDay.length - 3}",
                            style: GoogleFonts.manrope(
                              fontSize: 8,
                              color: AppColors.greyShade500Color,
                            ),
                          ),
                        ),
                    ],
                  ),
                ),
              );
            },
          ),
        ],
      ),
    );
  }

  static Widget _navButton({
    required IconData icon,
    required VoidCallback onTap,
  }) {
    return Container(
      decoration: BoxDecoration(
        color: AppColors.colorF3F3F5,
        borderRadius: BorderRadius.circular(8),
      ),
      child: IconButton(
        icon: Icon(icon, color: AppColors.color000000),
        onPressed: onTap,
      ),
    );
  }

  static Widget _legendDot(Color color, String label) {
    return Row(
      children: [
        Container(
          width: 8,
          height: 8,
          decoration: BoxDecoration(color: color, shape: BoxShape.circle),
        ),
        const SizedBox(width: 6),
        Text(
          label,
          style: GoogleFonts.manrope(fontSize: 14, fontWeight: FontWeight.w400),
        ),
      ],
    );
  }
}
