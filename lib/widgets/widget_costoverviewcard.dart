import 'package:flutter/material.dart';
import 'package:hugeicons/hugeicons.dart';
import 'package:mobo_employees/core/const/all_design.dart';

class WidgetQuickOverview extends StatelessWidget {
  final String count;
  final String title;
  final String subtitle;
  final Color color;
  final List<List<dynamic>> icon;
  final bool isDarkTheme;

  const WidgetQuickOverview({
    super.key,
    required this.count,
    required this.title,
    required this.subtitle,
    required this.color,
    required this.icon,
    required this.isDarkTheme,
  });

  @override
  Widget build(BuildContext context) {
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
                FittedBox(
                  alignment: Alignment.centerLeft,
                  fit: BoxFit.scaleDown,
                  child: Text(
                    count,
                    style: TextStyle(
                      fontSize: 30,
                      fontWeight: FontWeight.w800,
                      color: isDarkTheme ? Colors.white : AppColors.color101828,
                      height: 1.1,
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  title,
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                    color: isDarkTheme ? Colors.white : AppColors.color101828,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 4),
                Text(
                  subtitle,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 11,
                    height: 1.35,
                    color: isDarkTheme
                        ? Colors.white38
                        : AppColors.color6A7282,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 10),
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: color.withOpacity(isDarkTheme ? 0.22 : 0.12),
              borderRadius: BorderRadius.circular(12),
            ),
            child: HugeIcon(icon: icon, color: color, size: 24),
          ),
        ],
      ),
    );
  }
}
