import 'package:flutter/material.dart';
import 'package:mobo_employees/features/manager/manager_approvals/widgets/widget_timeoff_card.dart';
import 'package:mobo_employees/shared/widgets/calendar/leave_month_calendar.dart';
import 'package:shimmer/shimmer.dart';

class AppShimmer extends StatelessWidget {
  final double width;
  final double height;
  final BorderRadius borderRadius;

  const AppShimmer({
    super.key,
    required this.width,
    required this.height,
    this.borderRadius = const BorderRadius.all(Radius.circular(8)),
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Shimmer.fromColors(
      baseColor: isDark ? Colors.grey[800]! : Colors.grey.shade300,
      highlightColor: isDark ? Colors.grey[700]! : Colors.grey.shade100,
      child: Container(
        width: width,
        height: height,
        decoration: BoxDecoration(
          color: Colors.grey,
          borderRadius: borderRadius,
        ),
      ),
    );
  }
}

/// Placeholder for [LeaveMonthCalendar]: the same card, navigation row, legend,
/// weekday strip and week rows, so the calendar doesn't change size when it
/// arrives. Only for the first load — moving between months updates the
/// calendar in place and never shows this.
class CalendarShimmer extends StatelessWidget {
  const CalendarShimmer({super.key});

  /// Five week rows: what most months need.
  static const int _weeks = 5;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Container(
      decoration: LeaveMonthCalendar.cardDecoration(isDark),
      child: Column(
        children: [
          /// Previous / month / next
          Padding(
            padding: const EdgeInsets.all(12),
            child: Row(
              children: [
                AppShimmer(
                  width: 48,
                  height: 48,
                  borderRadius: BorderRadius.circular(12),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: AppShimmer(
                    width: double.infinity,
                    height: 48,
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                const SizedBox(width: 10),
                AppShimmer(
                  width: 48,
                  height: 48,
                  borderRadius: BorderRadius.circular(12),
                ),
              ],
            ),
          ),

          /// Legend
          const Padding(
            padding: EdgeInsets.only(bottom: 12),
            child: AppShimmer(width: 240, height: 16),
          ),

          /// Weekday strip
          const AppShimmer(
            width: double.infinity,
            height: 36,
            borderRadius: BorderRadius.zero,
          ),

          /// Week rows
          GridView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            padding: const EdgeInsets.only(bottom: 8),
            itemCount: _weeks * 7,
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 7,
              mainAxisExtent: LeaveMonthCalendar.rowHeight,
            ),
            itemBuilder: (_, __) => const Center(
              child: AppShimmer(
                width: 26,
                height: 26,
                borderRadius: BorderRadius.all(Radius.circular(13)),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// Mirrors `WidgetTimeOffCard`'s layout — the same padding, round photo, two
/// lines beside it, reason and equal buttons — so the card doesn't change size
/// when real data loads.
class WidgetTimeOffCardShimmer extends StatelessWidget {
  const WidgetTimeOffCardShimmer({super.key});

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    Widget bar(double height, {double? width, double radius = 6}) => Container(
      height: height,
      width: width,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(radius),
      ),
    );

    return Shimmer.fromColors(
      baseColor: isDark ? Colors.grey[800]! : Colors.grey.shade300,
      highlightColor: isDark ? Colors.grey[700]! : Colors.grey.shade100,
      child: Container(
        padding: const EdgeInsets.all(WidgetTimeOffCard.padding),
        decoration: WidgetTimeOffCard.decoration(isDark),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                /// Photo
                Container(
                  width: WidgetTimeOffCard.avatarSize,
                  height: WidgetTimeOffCard.avatarSize,
                  decoration: const BoxDecoration(
                    color: Colors.white,
                    shape: BoxShape.circle,
                  ),
                ),
                const SizedBox(width: WidgetTimeOffCard.avatarGap),

                /// Name + pill, and the details under them
                Expanded(
                  child: SizedBox(
                    height: WidgetTimeOffCard.avatarSize,
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Expanded(child: bar(14)),
                            const SizedBox(width: 8),
                            bar(18, width: 52, radius: 20),
                          ],
                        ),
                        bar(11, width: 150),
                      ],
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: WidgetTimeOffCard.reasonGap),

            /// Reason
            bar(13, width: double.infinity),
            const SizedBox(height: WidgetTimeOffCard.buttonsGap),

            /// Buttons
            Row(
              children: [
                Expanded(
                  child: bar(
                    WidgetTimeOffCard.buttonHeight,
                    radius: WidgetTimeOffCard.buttonRadius,
                  ),
                ),
                const SizedBox(width: WidgetTimeOffCard.buttonSpacing),
                Expanded(
                  child: bar(
                    WidgetTimeOffCard.buttonHeight,
                    radius: WidgetTimeOffCard.buttonRadius,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
