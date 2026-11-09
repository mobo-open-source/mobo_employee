import 'package:flutter/material.dart';
import 'package:shimmer/shimmer.dart';

import 'widget_employee_card.dart';

/// Loading placeholder for [WidgetEmployeeCard]: the same surface, padding,
/// avatar and text-column height, so the list doesn't change size or jump when
/// the employees arrive.
class WidgetEmployeeCardShimmer extends StatelessWidget {
  const WidgetEmployeeCardShimmer({super.key});

  /// A bar of [barHeight] centred in a line box of [lineHeight]; full width
  /// when [width] is null.
  static Widget _line(double lineHeight, double barHeight, double? width) =>
      SizedBox(
        height: lineHeight,
        child: Align(
          alignment: Alignment.centerLeft,
          child: Container(
            height: barHeight,
            width: width ?? double.infinity,
            color: Colors.grey,
          ),
        ),
      );

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

            /// Text shimmer — in the same fixed line boxes as the card's name /
            /// phone / email column, so it is the same height.
            Expanded(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _line(WidgetEmployeeCard.nameLineHeight, 14, 140),
                  const SizedBox(height: WidgetEmployeeCard.lineGap),
                  _line(WidgetEmployeeCard.detailLineHeight, 11, 90),
                  const SizedBox(height: WidgetEmployeeCard.lineGap),
                  _line(WidgetEmployeeCard.detailLineHeight, 11, null),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
