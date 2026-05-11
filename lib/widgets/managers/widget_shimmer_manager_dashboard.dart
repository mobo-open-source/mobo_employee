import 'package:flutter/material.dart';
import 'package:flutter_staggered_grid_view/flutter_staggered_grid_view.dart';
import 'package:shimmer/shimmer.dart';

class WidgetShimmerManagerDashboard extends StatelessWidget {
  const WidgetShimmerManagerDashboard({super.key});

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    final baseColor = isDark ? Colors.grey.shade800 : Colors.grey.shade300;
    final highlightColor = isDark ? Colors.grey.shade700 : Colors.grey.shade100;

    return Shimmer.fromColors(
      baseColor: baseColor,
      highlightColor: highlightColor,
      child: SingleChildScrollView(
        physics: const NeverScrollableScrollPhysics(),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const SizedBox(height: 20),

            ///  Welcome Card Shimmer
            _shimmerBox(height: 90, radius: 16),

            const SizedBox(height: 25),

            ///  Section Title
            _shimmerLine(width: 160),

            const SizedBox(height: 15),

            /// Quick Overview Grid
            StaggeredGrid.count(
              crossAxisCount: 2,
              mainAxisSpacing: 10,
              crossAxisSpacing: 10,
              children: List.generate(
                4,
                (_) => _shimmerBox(height: 110, radius: 16),
              ),
            ),

            const SizedBox(height: 25),

            ///  Section Title
            _shimmerLine(width: 140),

            const SizedBox(height: 15),

            ///  Today Reports Cards
            Column(
              children: List.generate(
                3,
                (_) => Padding(
                  padding: const EdgeInsets.only(bottom: 10),
                  child: _shimmerBox(height: 70, radius: 16),
                ),
              ),
            ),

            const SizedBox(height: 20),
          ],
        ),
      ),
    );
  }

  ///  Shimmer Rectangle
  static Widget _shimmerBox({required double height, double radius = 12}) {
    return Container(
      height: height,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(radius),
      ),
    );
  }

  /// Shimmer Title Line
  static Widget _shimmerLine({double width = 120}) {
    return Container(
      height: 16,
      width: width,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(8),
      ),
    );
  }
}
