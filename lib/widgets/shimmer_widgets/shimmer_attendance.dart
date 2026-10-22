import 'package:flutter/material.dart';
import 'package:shimmer/shimmer.dart';

class AttendancePageShimmer extends StatelessWidget {
  final bool isDarkTheme;

  const AttendancePageShimmer({super.key, this.isDarkTheme = false});

  Color get _baseColor =>
      isDarkTheme ? Colors.grey.shade800 : Colors.grey.shade200;

  Color get _highlightColor =>
      isDarkTheme ? Colors.grey.shade700 : Colors.grey.shade50;

  Widget _box({double height = 20, double width = double.infinity, double radius = 16}) {
    return Shimmer.fromColors(
      baseColor: _baseColor,
      highlightColor: _highlightColor,
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

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(16),
      child: SingleChildScrollView(
        child: Column(
          children: [
            _box(height: 70), /// checkout card
            const SizedBox(height: 12),
            _box(height: 320), /// calendar
            const SizedBox(height: 12),
            _box(height: 80), /// status card
            const SizedBox(height: 12),
            _box(height: 90), /// clock timeline
            const SizedBox(height: 12),
            _box(height: 20, width: 180, radius: 6), /// title
            const SizedBox(height: 10),
            _box(height: 120), /// monthly overview
          ],
        ),
      ),
    );
  }
}
