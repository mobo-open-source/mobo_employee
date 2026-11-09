import 'package:flutter/material.dart';

/// A "Quick Overview" figure: title at the top, the value and its caption in
/// the middle, and a short accent bar in [color] at the bottom.
///
/// The card is the dashboards' metric card — radius 18, 20px padding, soft
/// shadow — laid out in a two-column grid ([gridDelegate]).
class WidgetQuickOverview extends StatelessWidget {
  final String count;
  final String title;
  final String subtitle;

  /// The figure's semantic colour, shown as the accent bar.
  final Color color;
  final bool isDarkTheme;

  /// Opens the screen behind this figure; shows an arrow when set.
  final VoidCallback? onTap;

  const WidgetQuickOverview({
    super.key,
    required this.count,
    required this.title,
    required this.subtitle,
    required this.color,
    required this.isDarkTheme,
    this.onTap,
  });

  /// Height of every card in the grid — tall enough for the title, value,
  /// caption and accent bar to spread out.
  static const double height = 144;

  /// Two equal columns with a 12px gap, every card [height] tall.
  static const SliverGridDelegate gridDelegate =
      SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 2,
        crossAxisSpacing: 12,
        mainAxisSpacing: 12,
        mainAxisExtent: height,
      );

  static const double radius = 18;

  /// The card's surface, shared with the dashboard shimmers so loading and
  /// loaded cards don't jump.
  static BoxDecoration decoration(bool isDark) => BoxDecoration(
    color: isDark ? Colors.grey[850] : Colors.white,
    borderRadius: BorderRadius.circular(radius),
    boxShadow: [
      BoxShadow(
        color: Colors.black.withValues(alpha: isDark ? 0.3 : 0.05),
        blurRadius: 4,
        spreadRadius: 2,
        offset: const Offset(0, 2),
      ),
    ],
    border: isDark
        ? Border.all(
            color: Colors.grey[800]!.withValues(alpha: 0.5),
            width: 0.5,
          )
        : null,
  );

  @override
  Widget build(BuildContext context) {
    final borderRadius = BorderRadius.circular(radius);

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: borderRadius,
        child: Container(
          padding: const EdgeInsets.all(20),
          decoration: decoration(isDarkTheme),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text(
                      title,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                        letterSpacing: 0.2,
                        color: isDarkTheme
                            ? Colors.grey[300]
                            : Colors.grey[600],
                      ),
                    ),
                  ),
                  if (onTap != null)
                    Icon(
                      Icons.arrow_forward_ios,
                      size: 12,
                      color: Colors.grey[400],
                    ),
                ],
              ),

              // Value and caption stay together; the title, this pair and
              // the accent bar spread over the card's height.
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Shrinks a long value to fit instead of cutting it off.
                  FittedBox(
                    fit: BoxFit.scaleDown,
                    alignment: Alignment.centerLeft,
                    child: Text(
                      count,
                      maxLines: 1,
                      style: TextStyle(
                        fontSize: 24,
                        fontWeight: FontWeight.w700,
                        letterSpacing: -0.5,
                        color: isDarkTheme ? Colors.white : Colors.grey[900],
                      ),
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    subtitle,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontSize: 11,
                      // Semi-bold, as the title above it: at 11px the lighter
                      // weight read as faint beside the figure.
                      fontWeight: FontWeight.w600,
                      height: 1.3,
                      color: isDarkTheme ? Colors.grey[400] : Colors.grey[500],
                    ),
                  ),
                ],
              ),

              Container(
                height: 3,
                width: 40,
                decoration: BoxDecoration(
                  color: color,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
