import 'package:flutter/material.dart';
import 'package:mobo_employees/core/const/all_design.dart';
import 'package:shimmer/shimmer.dart';

class WidgetShimmerAttendancePage extends StatelessWidget {
  const WidgetShimmerAttendancePage({super.key});

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        ///  Search bar shimmer placeholder
        Shimmer.fromColors(
          baseColor: AppColors.greyShade300Color,
          highlightColor: Colors.grey.shade100,
          child: Container(
            height: 44,
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(6),
            ),
          ),
        ),

        const SizedBox(height: 15),

        /// "No filters applied" placeholder
        Shimmer.fromColors(
          baseColor: AppColors.greyShade300Color,
          highlightColor: Colors.grey.shade100,
          child: Align(
            alignment: Alignment.centerLeft,
            child: Container(width: 120, height: 12, color: Colors.white),
          ),
        ),

        const SizedBox(height: 10),

        ///  Table container shimmer
        Expanded(
          child: Container(
            decoration: BoxDecoration(
              color: AppColors.whiteColor,
              borderRadius: BorderRadius.circular(6),
            ),
            child: Column(
              children: [
                /// Table header shimmer
                Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 10,
                  ),
                  child: Shimmer.fromColors(
                    baseColor: AppColors.greyShade300Color,
                    highlightColor: Colors.grey.shade100,
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

                /// Attendance rows shimmer
                Expanded(
                  child: ListView.separated(
                    itemCount: 6,
                    separatorBuilder: (_, __) =>
                        Divider(height: 1, color: AppColors.colorE5E7EB),
                    itemBuilder: (_, __) => _AttendanceRowShimmer(),
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
  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      child: Shimmer.fromColors(
        baseColor: AppColors.greyShade300Color,
        highlightColor: Colors.grey.shade100,
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
