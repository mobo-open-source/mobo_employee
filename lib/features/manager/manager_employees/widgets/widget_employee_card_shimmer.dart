import 'package:flutter/material.dart';
import 'package:shimmer/shimmer.dart';

import 'widget_employee_card.dart';

/// Loading placeholder for [WidgetEmployeeCard]: the same surface, padding,
/// avatar and text-column height, so the list doesn't change size or jump when
/// the employees arrive.
class WidgetEmployeeCardShimmer extends StatelessWidget {
  const WidgetEmployeeCardShimmer({super.key});

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Shimmer.fromColors(
      baseColor: isDark ? Colors.grey[800]! : Colors.grey.shade300,
      highlightColor: isDark ? Colors.grey[700]! : Colors.grey.shade100,
      child: Container(
        padding: WidgetEmployeeCard.padding,
        decoration: WidgetEmployeeCard.decoration(isDark),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            /// Avatar shimmer
            Container(
              height: WidgetEmployeeCard.avatarSize,
              width: WidgetEmployeeCard.avatarSize,
              decoration: BoxDecoration(
                color: Colors.grey,
                borderRadius: BorderRadius.circular(10),
              ),
            ),

            const SizedBox(width: WidgetEmployeeCard.avatarGap),

            /// Text shimmer — 15 + 11 + 11 + 11 + 11 = 59, the height of the
            /// card's name / phone / email column.
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(height: 15, width: 140, color: Colors.grey),
                  const SizedBox(height: 11),
                  Container(height: 11, width: 90, color: Colors.grey),
                  const SizedBox(height: 11),
                  Container(
                    height: 11,
                    width: double.infinity,
                    color: Colors.grey,
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
