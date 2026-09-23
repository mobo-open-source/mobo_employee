import 'package:flutter/material.dart';
import 'package:hugeicons/hugeicons.dart';
import 'package:mobo_employees/core/const/all_design.dart';

class WidgetRecentActivity extends StatelessWidget {
  final String title;
  final String subtitle;
  final Color color;
  final String? statusText;
  final Color? statusColor;
  final List<List<dynamic>> icon;
  final bool isDarkTheme;

  const WidgetRecentActivity({
    super.key,
    required this.title,
    required this.subtitle,
    this.statusText,
    this.statusColor,
    required this.color,
    required this.icon,
    required this.isDarkTheme,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
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
      padding: const EdgeInsets.all(15),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: color.withOpacity(isDarkTheme ? 0.22 : 0.12),
              borderRadius: BorderRadius.circular(12),
            ),
            child: HugeIcon(icon: icon, color: color, size: 22),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  title,
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                    letterSpacing: 0,
                    color: isDarkTheme
                        ? AppColors.white
                        : AppColors.Color3F3F3F,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 4),
                Text(
                  subtitle,
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    letterSpacing: 0,
                    color: isDarkTheme
                        ? AppColors.whiteColor
                        : AppColors.Color4E4E4E,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
          const SizedBox(width: 10),
          if (statusText != null && statusText!.isNotEmpty)
            Container(
              padding: const EdgeInsets.symmetric(vertical: 5, horizontal: 10),
              decoration: BoxDecoration(
                color:
                    statusColor?.withOpacity(0.12) ??
                    Colors.grey.withOpacity(0.12),
                borderRadius: BorderRadius.circular(20),
              ),
              child: Text(
                statusText!,
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: statusColor ?? Colors.grey,
                ),
              ),
            ),
        ],
      ),
    );
  }
}
