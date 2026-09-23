import 'package:flutter/material.dart';
import 'package:shimmer/shimmer.dart';
import 'package:mobo_employees/core/const/all_design.dart';

/// Mirrors ManagerDashboardPage's own layout so there's no visible jump in
/// size or alignment when the real data swaps in.
class WidgetShimmerManagerDashboard extends StatelessWidget {
  const WidgetShimmerManagerDashboard({super.key});

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final baseColor = isDark ? Colors.grey.shade700 : Colors.grey.shade300;
    final highlightColor = isDark ? Colors.grey.shade600 : Colors.grey.shade100;
    const onAccentBase = Color(0xFFD98CA1);
    const onAccentHighlight = Color(0xFFF0C6D2);

    Widget line({
      required double width,
      required double height,
      double radius = 6,
      Color? base,
      Color? highlight,
    }) {
      return Shimmer.fromColors(
        baseColor: base ?? baseColor,
        highlightColor: highlight ?? highlightColor,
        child: Container(
          width: width,
          height: height,
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(radius),
          ),
        ),
      );
    }

    Widget box({
      required double height,
      required double width,
      double radius = 12,
    }) {
      return Shimmer.fromColors(
        baseColor: baseColor,
        highlightColor: highlightColor,
        child: Container(
          height: height,
          width: width,
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(radius),
          ),
        ),
      );
    }

    Widget circle({required double diameter}) {
      return Shimmer.fromColors(
        baseColor: onAccentBase,
        highlightColor: onAccentHighlight,
        child: Container(
          width: diameter,
          height: diameter,
          decoration: const BoxDecoration(
            shape: BoxShape.circle,
            color: Colors.white,
          ),
        ),
      );
    }

    /// Matches WidgetManagerWelcomeCard.
    Widget welcomeCardShimmer() {
      return Container(
        width: double.infinity,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(10),
          color: AppColors.appColor,
        ),
        padding: const EdgeInsets.only(left: 15, right: 15, top: 28, bottom: 28),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  line(width: 210, height: 16, base: onAccentBase, highlight: onAccentHighlight),
                  const SizedBox(height: 10),
                  line(width: 160, height: 13, base: onAccentBase, highlight: onAccentHighlight),
                ],
              ),
            ),
            const SizedBox(width: 16),
            circle(diameter: 60),
          ],
        ),
      );
    }

    /// Matches WidgetQuickOverview: count/title/subtitle lines + icon chip.
    Widget quickOverviewCardShimmer() {
      return Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: isDark ? AppColors.greyShade800Color : AppColors.whiteColor,
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(isDark ? 0.2 : 0.04),
              blurRadius: 10,
              offset: const Offset(0, 3),
            ),
          ],
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  line(width: 36, height: 26),
                  const SizedBox(height: 6),
                  line(width: 80, height: 12),
                  const SizedBox(height: 4),
                  line(width: 100, height: 10),
                ],
              ),
            ),
            const SizedBox(width: 10),
            box(height: 40, width: 40, radius: 12),
          ],
        ),
      );
    }

    /// Matches WidgetRecentActivity: icon chip + title/subtitle lines.
    Widget recentActivityCardShimmer() {
      return Container(
        width: double.infinity,
        decoration: BoxDecoration(
          color: isDark ? AppColors.greyShade800Color : AppColors.whiteColor,
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(isDark ? 0.2 : 0.04),
              blurRadius: 10,
              offset: const Offset(0, 3),
            ),
          ],
        ),
        padding: const EdgeInsets.all(15),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            box(height: 40, width: 40, radius: 12),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  line(width: double.infinity, height: 15),
                  const SizedBox(height: 6),
                  line(width: 150, height: 12),
                ],
              ),
            ),
          ],
        ),
      );
    }

    return SingleChildScrollView(
      physics: const AlwaysScrollableScrollPhysics(),
      padding: const EdgeInsets.all(15),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          welcomeCardShimmer(),
          const SizedBox(height: 18),

          /// "Quick Overview" title
          line(width: 150, height: 18),
          const SizedBox(height: 16),
          GridView.count(
            crossAxisCount: 2,
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            crossAxisSpacing: 12,
            mainAxisSpacing: 12,
            childAspectRatio: 1.2,
            children: List.generate(4, (_) => quickOverviewCardShimmer()),
          ),
          const SizedBox(height: 18),

          /// "Today's Reports" title
          line(width: 150, height: 18),
          const SizedBox(height: 16),
          recentActivityCardShimmer(),
          const SizedBox(height: 10),
          recentActivityCardShimmer(),
          const SizedBox(height: 10),
          recentActivityCardShimmer(),
        ],
      ),
    );
  }
}
