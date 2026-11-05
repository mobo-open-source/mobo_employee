import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:mobo_employees/core/const/all_design.dart';
import 'package:mobo_employees/core/theme/app_theme.dart';

/// A time off drawn on the calendar: the days it covers and the colour of its
/// status dot.
class LeaveCalendarMark {
  final DateTime from;
  final DateTime to;
  final Color color;

  const LeaveCalendarMark({
    required this.from,
    required this.to,
    required this.color,
  });

  /// Whether [day] falls within [from]..[to], by date alone.
  bool covers(DateTime day) {
    final d = DateUtils.dateOnly(day);
    return !d.isBefore(DateUtils.dateOnly(from)) &&
        !d.isAfter(DateUtils.dateOnly(to));
  }
}

/// The month calendar of the Approvals and Leave pages, drawn as the events
/// app's calendar: one rounded card holding a brand-filled
/// previous / month / next row, a pale brand-tint weekday strip and the month
/// grid. A day is a centred number; today is a pale brand circle, the selected
/// day a 2px brand ring, and the time off on a day are small dots under the
/// number, in their status colours (the legend says which is which).
///
/// Presentational only: the month, selection and marks come in, and taps go
/// out, so the Approvals page (manager) and the Leave page (employee) share it.
class LeaveMonthCalendar extends StatelessWidget {
  /// Any day of the month shown.
  final DateTime month;
  final DateTime? selectedDate;
  final List<LeaveCalendarMark> marks;

  /// Days drawn greyed out (holidays, non-working days), keyed by the day at
  /// midnight.
  final Map<DateTime, bool> unusualDays;
  final VoidCallback onPreviousMonth;
  final VoidCallback onNextMonth;
  final ValueChanged<DateTime> onSelectDate;

  /// The day that gets the "today" circle. The current day when null.
  final DateTime? today;

  const LeaveMonthCalendar({
    super.key,
    required this.month,
    required this.selectedDate,
    required this.marks,
    required this.unusualDays,
    required this.onPreviousMonth,
    required this.onNextMonth,
    required this.onSelectDate,
    this.today,
  });

  /// Height of a week row — as the events calendar's.
  static const double rowHeight = 52;

  /// Diameter of the today circle and the selected ring.
  static const double ring = 40;

  /// Height of the month navigation row: 48 buttons in 12px of padding.
  static const double navHeight = 72;

  /// At most this many dots under a day; the rest read "+N".
  static const int maxDots = 3;

  static const List<String> _weekdays = [
    'SUN',
    'MON',
    'TUE',
    'WED',
    'THU',
    'FRI',
    'SAT',
  ];

  /// The card surface: events' calendar card (radius 12, the standard card
  /// shadow). Shared with the loading placeholder.
  static BoxDecoration cardDecoration(bool isDark) => BoxDecoration(
    color: isDark ? AppColors.greyShade800Color : Colors.white,
    borderRadius: BorderRadius.circular(AppRadius.defaultRadius),
    boxShadow: const [AppShadows.cardShadow],
  );

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final dayColor = isDark ? Colors.white : AppColors.blackColor;

    final daysInMonth = DateUtils.getDaysInMonth(month.year, month.month);

    /// Sunday-first: how many blank cells come before the 1st.
    final leading = DateTime(month.year, month.month, 1).weekday % 7;

    return Container(
      decoration: cardDecoration(isDark),
      child: Column(
        children: [
          _header(isDark),

          /// Legend: which dot colour is which status. Scales down on a very
          /// narrow card rather than overflowing it.
          Padding(
            padding: const EdgeInsets.fromLTRB(12, 0, 12, 12),
            child: FittedBox(
              fit: BoxFit.scaleDown,
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  _legendDot(AppColors.color007AFF, 'Validated', dayColor),
                  const SizedBox(width: 20),
                  _legendDot(AppColors.colorFFAA00, 'To Approve', dayColor),
                  const SizedBox(width: 20),
                  _legendDot(AppColors.ColorF90000, 'Refused', dayColor),
                ],
              ),
            ),
          ),

          _weekdayStrip(isDark),

          GridView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            padding: const EdgeInsets.only(bottom: 8),
            itemCount: leading + daysInMonth,
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 7,
              mainAxisExtent: rowHeight,
            ),
            itemBuilder: (context, index) {
              if (index < leading) return const SizedBox.shrink();
              final date = DateTime(
                month.year,
                month.month,
                index - leading + 1,
              );
              return _dayCell(date, isDark, dayColor);
            },
          ),
        ],
      ),
    );
  }

  /// Previous / month name / next: the arrows and the month are one family of
  /// brand-filled buttons, as in the events app.
  Widget _header(bool isDark) {
    Widget arrow(IconData icon, String tooltip, VoidCallback onTap) => Material(
      color: AppTheme.primaryColor,
      borderRadius: BorderRadius.circular(AppRadius.defaultRadius),
      clipBehavior: Clip.antiAlias,
      child: IconButton(
        tooltip: tooltip,
        color: Colors.white,
        icon: Icon(icon),
        onPressed: onTap,
      ),
    );

    return Padding(
      padding: const EdgeInsets.all(12),
      child: Row(
        children: [
          arrow(Icons.chevron_left, 'Previous month', onPreviousMonth),
          const SizedBox(width: 10),
          Expanded(
            child: Container(
              padding: const EdgeInsets.symmetric(vertical: 13),
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: AppTheme.primaryColor,
                borderRadius: BorderRadius.circular(AppRadius.defaultRadius),
              ),
              child: Text(
                DateFormat('MMMM yyyy').format(month),
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ),
          const SizedBox(width: 10),
          arrow(Icons.chevron_right, 'Next month', onNextMonth),
        ],
      ),
    );
  }

  /// The day names on a pale brand-tint band, in the brand colour (white on a
  /// faint wash in dark mode). Each name takes a seventh of the width, so it
  /// sits over its column of the grid.
  Widget _weekdayStrip(bool isDark) {
    final style = TextStyle(
      color: isDark ? Colors.white : AppTheme.primaryColor,
      fontSize: 12,
      fontWeight: FontWeight.w500,
    );
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(vertical: 10),
      color: isDark
          ? Colors.white.withValues(alpha: 0.12)
          : AppColors.primaryTint,
      child: Row(
        children: [
          for (final day in _weekdays)
            Expanded(
              child: Center(child: Text(day, style: style)),
            ),
        ],
      ),
    );
  }

  Widget _dayCell(DateTime date, bool isDark, Color dayColor) {
    final isSelected =
        selectedDate != null && DateUtils.isSameDay(selectedDate, date);
    final isToday = DateUtils.isSameDay(today ?? DateTime.now(), date);
    final isUnusual = unusualDays[date] == true;
    final colors = [
      for (final mark in marks)
        if (mark.covers(date)) mark.color,
    ];

    return GestureDetector(
      key: ValueKey('calendar_day_${date.day}'),
      behavior: HitTestBehavior.opaque,
      onTap: () => onSelectDate(date),
      child: Stack(
        alignment: Alignment.center,
        children: [
          Container(
            width: ring,
            height: ring,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              // The ring wins on a selected today, as in the events calendar.
              color: isToday && !isSelected
                  ? (isDark
                        ? AppTheme.primaryColor.withValues(alpha: 0.18)
                        : const Color(0xFFF6DCDC))
                  : null,
              border: isSelected
                  ? Border.all(color: AppTheme.primaryColor, width: 2)
                  : null,
            ),
            child: Text(
              '${date.day}',
              style: TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.w600,
                color: isUnusual ? AppColors.greyShade500Color : dayColor,
              ),
            ),
          ),
          if (colors.isNotEmpty) Positioned(bottom: 6, child: _dots(colors)),
        ],
      ),
    );
  }

  /// Up to [maxDots] status dots, then how many more there are.
  Widget _dots(List<Color> colors) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        for (final color in colors.take(maxDots))
          Container(
            margin: const EdgeInsets.symmetric(horizontal: 2),
            width: 6,
            height: 6,
            decoration: BoxDecoration(shape: BoxShape.circle, color: color),
          ),
        if (colors.length > maxDots)
          Text(
            '+${colors.length - maxDots}',
            style: TextStyle(fontSize: 8, color: AppColors.greyShade500Color),
          ),
      ],
    );
  }

  static Widget _legendDot(Color color, String label, Color labelColor) {
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
          style: TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w400,
            color: labelColor,
          ),
        ),
      ],
    );
  }
}
