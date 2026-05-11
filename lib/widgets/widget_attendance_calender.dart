import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:mobo_employees/features/employee/attendance/provider/attendance_provider.dart';
import 'package:mobo_employees/features/employee/dashboard/provider/dashboard_provider.dart';
import 'package:provider/provider.dart';
import 'package:table_calendar/table_calendar.dart';
import '../core/const/all_design.dart';

class WidgetAttendanceCalender extends StatefulWidget {
  WidgetAttendanceCalender({super.key});

  @override
  State<WidgetAttendanceCalender> createState() =>
      _WidgetAttendanceCalenderState();
}

class _WidgetAttendanceCalenderState extends State<WidgetAttendanceCalender> {
  @override
  Widget build(BuildContext context) {
    final attendanceProvider = context.read<AttendanceProvider>();
    final employeeId = attendanceProvider.attendanceEmployeeModel?.id;
    final focusedDay = attendanceProvider.focusedDay;
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: AppColors.color000000.withOpacity(.04),
            offset: const Offset(3, 11),
            blurRadius: 8.5,
            spreadRadius: -3,
          ),
        ],
      ),
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12),
            child: _monthContainer(
              focusedDay: focusedDay,
              onPrevious: () {
                final newMonth = DateTime(
                  focusedDay.year,
                  focusedDay.month - 1,
                );

                attendanceProvider.updateCalendarMonth(newMonth);
                attendanceProvider.focusedDay = newMonth;

                attendanceProvider.refreshCalendarMonth(
                  employeeId: attendanceProvider.attendanceEmployeeModel!.id,
                  month: newMonth,
                );
              },
              onNext: () {
                final newMonth = DateTime(
                  focusedDay.year,
                  focusedDay.month + 1,
                );
                attendanceProvider.updateCalendarMonth(newMonth);
                attendanceProvider.focusedDay = newMonth;
                attendanceProvider.refreshCalendarMonth(
                  employeeId: attendanceProvider.attendanceEmployeeModel!.id,
                  month: newMonth,
                );
              },
            ),
          ),
          _legendContainer(),
          Container(
            padding: const EdgeInsets.only(bottom: 10),
            decoration: BoxDecoration(borderRadius: BorderRadius.circular(12)),
            child: TableCalendar(
              rowHeight: 48,
              firstDay: DateTime.utc(2020, 1, 1),
              lastDay: DateTime.utc(2030, 12, 31),
              focusedDay: focusedDay,
              calendarFormat: CalendarFormat.month,
              selectedDayPredicate: (day) => isSameDay(
                context.watch<AttendanceProvider>().selectedDay,
                day,
              ),
              onDaySelected: (selectedDay, focusedDay) {
                final employeeId = Provider.of<DashboardProvider>(
                  context,
                  listen: false,
                ).employeeId;
                if (employeeId == null) {
                  return;
                }
                attendanceProvider.selectDay(
                  selectedDay,
                  focusedDay,
                  employeeId,
                );
              },
              onPageChanged: (newFocusedDay) {
                attendanceProvider.focusedDay = DateTime(
                  newFocusedDay.year,
                  newFocusedDay.month,
                );
              },
              daysOfWeekVisible: true,
              daysOfWeekHeight: 32,
              daysOfWeekStyle: DaysOfWeekStyle(
                decoration: BoxDecoration(color: AppColors.colorF8F9FA),
                weekdayStyle: TextStyle(
                  color: AppColors.color6A7282,
                  fontSize: 12,
                  fontWeight: FontWeight.w500,
                ),
                weekendStyle: TextStyle(
                  color: AppColors.color6A7282,
                  fontSize: 12,
                  fontWeight: FontWeight.w500,
                ),
              ),

              calendarBuilders: CalendarBuilders(
                defaultBuilder: (context, day, focusedDay) =>
                    _CalendarDayContainer(day: day),
                todayBuilder: (context, day, focusedDay) =>
                    _CalendarDayContainer(day: day, isToday: true),
                selectedBuilder: (context, day, focusedDay) =>
                    _CalendarDayContainer(day: day, isSelected: true),
              ),
              headerStyle: const HeaderStyle(
                headerPadding: EdgeInsets.symmetric(vertical: 5),
                titleTextStyle: TextStyle(fontSize: 0),
                leftChevronVisible: false,
                rightChevronVisible: false,
                formatButtonVisible: false,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

Widget _legendContainer() {
  return Container(
    padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 20),
    child: Row(
      crossAxisAlignment: CrossAxisAlignment.center,
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        _LegendDot(color: AppColors.Color00A63E, text: 'Present'),
        const SizedBox(width: 5),
        _LegendDot(color: AppColors.colorFFAA00, text: 'Absent'),
        const SizedBox(width: 5),
        _LegendDot(color: AppColors.ColorF90000, text: 'Leave'),
        const SizedBox(width: 5),
        _LegendDot(color: AppColors.ColorD9D9D9, text: 'Holiday'),
      ],
    ),
  );
}

class _CalendarDayContainer extends StatelessWidget {
  final DateTime day;
  final bool isToday;
  final bool isSelected;

  const _CalendarDayContainer({
    required this.day,
    this.isToday = false,
    this.isSelected = false,
  });

  @override
  Widget build(BuildContext context) {
    final isLeave = context.select<AttendanceProvider, bool>(
      (p) => p.isLeave(day),
    );
    final isUnusual = context.select<AttendanceProvider, bool>(
      (p) => p.isUnusual(day),
    );
    final isHoliday = context.select<AttendanceProvider, bool>(
      (p) => p.isHoliday(day),
    );
    final isPresent = context.select<AttendanceProvider, bool>(
      (p) => p.isPresent(day),
    );

    final isWeekend =
        day.weekday == DateTime.saturday || day.weekday == DateTime.sunday;
    final now = DateTime.now();
    final todayOnly = DateTime(now.year, now.month, now.day);
    final calendarDay = DateTime(day.year, day.month, day.day);

    final isPastOrToday =
        calendarDay.isBefore(todayOnly) || calendarDay == todayOnly;

    Color bgColor = AppColors.white;
    Color textColor = AppColors.color000000;
    final highlight = isToday || isSelected;
    return Padding(
      padding: const EdgeInsets.all(4),
      child: Container(
        decoration: BoxDecoration(borderRadius: BorderRadius.circular(10)),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(
                shape: BoxShape.circle,

                border: Border.all(
                  color: highlight ? AppColors.blue : Colors.white,
                ),
              ),
              child: Text(
                '${day.day}',
                style: TextStyle(
                  fontSize: 17,
                  fontWeight: FontWeight.w500,
                  color: isUnusual ? AppColors.ColorD9D9D9 : textColor,
                ),
              ),
            ),

            if (isPastOrToday) ...[
              if (isLeave)
                _CalendarDot(color: AppColors.ColorF90000)
              else if (!isPresent && !isWeekend)
                _CalendarDot(color: AppColors.colorF59E0B)
              else if (isPresent)
                _CalendarDot(color: AppColors.Color00A63E)
              else if (isHoliday)
                _CalendarDot(color: AppColors.grey)
              else
                const SizedBox(height: 6),
            ] else
              const SizedBox(height: 6),
          ],
        ),
      ),
    );
  }
}

Widget _monthContainer({
  required DateTime focusedDay,
  required VoidCallback onPrevious,
  required VoidCallback onNext,
}) {
  return Container(
    padding: const EdgeInsets.symmetric(vertical: 12),
    decoration: BoxDecoration(borderRadius: BorderRadius.circular(10)),
    child: Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Container(
          decoration: BoxDecoration(
            color: AppColors.colorF3F3F5,
            borderRadius: BorderRadius.circular(8),
          ),
          child: IconButton(
            icon: const Icon(Icons.chevron_left),
            onPressed: onPrevious,
          ),
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
              DateFormat('MMMMyyyy').format(focusedDay),
              textAlign: TextAlign.center,
              style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
            ),
          ),
        ),
        const SizedBox(width: 10),
        Container(
          decoration: BoxDecoration(
            color: AppColors.colorF3F3F5,
            borderRadius: BorderRadius.circular(8),
          ),
          child: IconButton(
            icon: const Icon(Icons.chevron_right),
            onPressed: onNext,
          ),
        ),
      ],
    ),
  );
}

class _LegendDot extends StatelessWidget {
  final Color color;
  final String text;
  const _LegendDot({required this.color, required this.text});
  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.center,
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Container(
          width: 10,
          height: 10,
          decoration: BoxDecoration(color: color, shape: BoxShape.circle),
        ),
        const SizedBox(width: 3),
        Text(
          text,
          style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w400),
        ),
      ],
    );
  }
}

class _CalendarDot extends StatelessWidget {
  final Color color;
  const _CalendarDot({required this.color});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 6,
      height: 6,
      decoration: BoxDecoration(color: color, shape: BoxShape.circle),
    );
  }
}
