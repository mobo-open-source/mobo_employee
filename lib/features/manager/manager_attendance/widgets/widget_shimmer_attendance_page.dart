import 'package:flutter/material.dart';
import 'package:mobo_employees/core/const/all_design.dart';
import 'package:shimmer/shimmer.dart';

class WidgetShimmerAttendancePage extends StatelessWidget {
  const WidgetShimmerAttendancePage({super.key});

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final base = isDark ? Colors.grey[800]! : AppColors.greyShade300Color;
    final highlight = isDark ? Colors.grey[700]! : Colors.grey.shade100;
    return Column(
      children: [
        Shimmer.fromColors(
          baseColor: base,
          highlightColor: highlight,
          child: Container(
            height: 44,
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(6),
            ),
          ),
        ),

        const SizedBox(height: 15),

        Shimmer.fromColors(
          baseColor: base,
          highlightColor: highlight,
          child: Align(
            alignment: Alignment.centerLeft,
            child: Container(width: 120, height: 12, color: Colors.white),
          ),
        ),

        const SizedBox(height: 10),

        Expanded(
          child: Container(
            decoration: BoxDecoration(
              color: isDark ? AppColors.greyShade800Color : AppColors.whiteColor,
              borderRadius: BorderRadius.circular(6),
            ),
            child: Column(
              children: [
                Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 10,
                  ),
                  child: Shimmer.fromColors(
                    baseColor: base,
                    highlightColor: highlight,
                    child: Container(
                      height: 36,
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(4),
                      ),
                    ),
                  ),
                ),

                const SizedBox(height: 10),

                Expanded(
                  child: ListView.separated(
                    itemCount: 6,
                    separatorBuilder: (_, __) =>
                        Divider(
                          height: 1,
                          color: isDark ? Colors.white12 : AppColors.colorE5E7EB,
                        ),
                    itemBuilder: (_, __) =>
                        _AttendanceRowShimmer(base: base, highlight: highlight),
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

class _AttendanceRowShimmer extends StatelessWidget {
  final Color base;
  final Color highlight;

  const _AttendanceRowShimmer({required this.base, required this.highlight});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      child: Shimmer.fromColors(
        baseColor: base,
        highlightColor: highlight,
        child: Row(
          children: [
            const CircleAvatar(radius: 16, backgroundColor: Colors.white),
            const SizedBox(width: 10),

            Expanded(
              flex: 5,
              child: Container(height: 12, color: Colors.white),
            ),
            const SizedBox(width: 10),

            Expanded(
              flex: 3,
              child: Container(height: 12, color: Colors.white),
            ),
            const SizedBox(width: 10),

            Expanded(
              flex: 3,
              child: Container(height: 12, color: Colors.white),
            ),
            const SizedBox(width: 10),

            Expanded(
              flex: 3,
              child: Container(height: 12, color: Colors.white),
            ),
          ],
        ),
      ),
    );
  }
}
