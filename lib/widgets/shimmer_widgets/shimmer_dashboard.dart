import 'package:flutter/material.dart';
import 'package:shimmer/shimmer.dart';
import 'package:mobo_employees/core/const/all_design.dart';

/// Mirrors the real dashboard's own layout so there's no visible jump in
/// size or alignment when the real data swaps in.
class DashboardShimmer extends StatelessWidget {
  final bool isDarkTheme;

  const DashboardShimmer({super.key, required this.isDarkTheme});

  Color get _baseColor =>
      isDarkTheme ? Colors.grey.shade700 : Colors.grey.shade300;

  Color get _highlightColor =>
      isDarkTheme ? Colors.grey.shade600 : Colors.grey.shade100;

  /// Tinted pink so the placeholder blocks stay legible against the welcome
  /// card's solid `AppColors.appColor` background.
  Color get _onAccentBase => const Color(0xFFD98CA1);

  Color get _onAccentHighlight => const Color(0xFFF0C6D2);

  Widget _line({
    required double width,
    required double height,
    double radius = 6,
    Color? base,
    Color? highlight,
  }) {
    return Shimmer.fromColors(
      baseColor: base ?? _baseColor,
      highlightColor: highlight ?? _highlightColor,
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

  Widget _box({
    required double height,
    required double width,
    double radius = 12,
    Color? base,
    Color? highlight,
  }) {
    return Shimmer.fromColors(
      baseColor: base ?? _baseColor,
      highlightColor: highlight ?? _highlightColor,
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

  Widget _circle({required double diameter, Color? base, Color? highlight}) {
    return Shimmer.fromColors(
      baseColor: base ?? _baseColor,
      highlightColor: highlight ?? _highlightColor,
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

  Widget _cardDecoration({required Widget child, EdgeInsetsGeometry? padding}) {
    return Container(
      width: double.infinity,
      padding: padding ?? const EdgeInsets.symmetric(horizontal: 18, vertical: 16),
      decoration: BoxDecoration(
        color: isDarkTheme ? AppColors.greyShade800Color : Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: isDarkTheme
              ? AppColors.greyShade700Color
              : const Color(0xFFE0E0E0),
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(isDarkTheme ? 0.25 : 0.06),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: child,
    );
  }

  /// Matches WelcomeCard: colour="AppColors.appColor", padding
  /// left/right 15, top/bottom 28, greeting text left + 60x60 avatar right.
  Widget _welcomeCardShimmer() {
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
                _line(
                  width: 210,
                  height: 16,
                  base: _onAccentBase,
                  highlight: _onAccentHighlight,
                ),
                const SizedBox(height: 10),
                _line(
                  width: 160,
                  height: 13,
                  base: _onAccentBase,
                  highlight: _onAccentHighlight,
                ),
              ],
            ),
          ),
          const SizedBox(width: 16),
          _circle(diameter: 60, base: _onAccentBase, highlight: _onAccentHighlight),
        ],
      ),
    );
  }

  /// Matches WidgetCheckInCard: icon chip + two text lines + action pill.
  Widget _checkInCardShimmer() {
    return _cardDecoration(
      child: Row(
        children: [
          _box(height: 44, width: 44, radius: 12),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                _line(width: 96, height: 14),
                const SizedBox(height: 7),
                _line(width: 64, height: 11),
              ],
            ),
          ),
          const SizedBox(width: 10),
          _box(height: 38, width: 100, radius: 10),
        ],
      ),
    );
  }

  /// Matches WidgetQuickOverview: count/title/subtitle lines + icon chip.
  Widget _quickOverviewCardShimmer() {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: isDarkTheme ? AppColors.greyShade800Color : AppColors.whiteColor,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(isDarkTheme ? 0.2 : 0.04),
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
                _line(width: 44, height: 26),
                const SizedBox(height: 6),
                _line(width: 70, height: 12),
                const SizedBox(height: 4),
                _line(width: 90, height: 10),
              ],
            ),
          ),
          const SizedBox(width: 10),
          _box(height: 40, width: 40, radius: 12),
        ],
      ),
    );
  }

  /// Matches WidgetRecentActivity: icon chip + title/subtitle lines.
  Widget _recentActivityCardShimmer() {
    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        color: isDarkTheme ? AppColors.greyShade800Color : AppColors.whiteColor,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(isDarkTheme ? 0.2 : 0.04),
            blurRadius: 10,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      padding: const EdgeInsets.all(15),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _box(height: 40, width: 40, radius: 12),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                _line(width: double.infinity, height: 15),
                const SizedBox(height: 6),
                _line(width: 150, height: 12),
              ],
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      physics: const AlwaysScrollableScrollPhysics(),
      padding: const EdgeInsets.all(15),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _welcomeCardShimmer(),
          const SizedBox(height: 18),
          _checkInCardShimmer(),
          const SizedBox(height: 18),

          /// "Quick Overview" title
          _line(width: 150, height: 18),
          const SizedBox(height: 16),
          GridView.count(
            crossAxisCount: 2,
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            crossAxisSpacing: 12,
            mainAxisSpacing: 12,
            childAspectRatio: 1.2,
            children: List.generate(6, (_) => _quickOverviewCardShimmer()),
          ),
          const SizedBox(height: 18),

          /// "Recent Activity" title
          _line(width: 150, height: 18),
          const SizedBox(height: 16),
          _recentActivityCardShimmer(),
          const SizedBox(height: 10),
          _recentActivityCardShimmer(),
        ],
      ),
    );
  }
}
