import 'package:flutter/material.dart';
import 'package:flutter_staggered_grid_view/flutter_staggered_grid_view.dart';
import 'package:shimmer/shimmer.dart';

class DashboardShimmer extends StatelessWidget {
  final bool isDarkTheme;

  const DashboardShimmer({super.key, required this.isDarkTheme});

  Color get _baseColor =>
      isDarkTheme ? Colors.grey.shade800 : Colors.grey.shade300;

  Color get _highlightColor =>
      isDarkTheme ? Colors.grey.shade700 : Colors.grey.shade100;

  Widget _box({required double height, double radius = 14}) {
    return Shimmer.fromColors(
      baseColor: _baseColor,
      highlightColor: _highlightColor,
      child: Container(
        height: height,
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(radius),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      physics: const AlwaysScrollableScrollPhysics(),
      child: Column(
        children: [
          const SizedBox(height: 20),

          /// Welcome card
          _box(height: 90, radius: 16),

          const SizedBox(height: 10),

          /// Check-in card
          _box(height: 95, radius: 16),

          const SizedBox(height: 20),

          /// Quick overview grid
          StaggeredGrid.count(
            crossAxisCount: 2,
            mainAxisSpacing: 10,
            crossAxisSpacing: 10,
            children: List.generate(
              6,
              (_) => StaggeredGridTile.fit(
                crossAxisCellCount: 1,
                child: _box(height: 110),
              ),
            ),
          ),

          const SizedBox(height: 20),

          /// Recent activity
          _box(height: 130, radius: 16),

          const SizedBox(height: 20),
        ],
      ),
    );
  }
}
