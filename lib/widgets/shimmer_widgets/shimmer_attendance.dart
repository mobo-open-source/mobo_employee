import 'package:flutter/material.dart';

class AttendancePageShimmer extends StatelessWidget {
  const AttendancePageShimmer({super.key});

  Widget _box({double height = 20, double width = double.infinity}) {
    return Container(
      height: height,
      width: width,
      decoration: BoxDecoration(
        color: Colors.grey.shade300,
        borderRadius: BorderRadius.circular(8),
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
            _box(height: 20, width: 180), /// title
            const SizedBox(height: 10),
            _box(height: 120), /// monthly overview
          ],
        ),
      ),
    );
  }
}
