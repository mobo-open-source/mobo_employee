import 'package:flutter/material.dart';
import 'package:hugeicons/hugeicons.dart';
import 'package:mobo_employees/core/const/all_design.dart';
import 'package:mobo_employees/core/theme/app_theme.dart';

class WidgetRecentActivity extends StatelessWidget {
  final String title;
  final String subtitle;
  final Color color;
  final String? statusText;
  final Color? statusColor;
  final List<List<dynamic>> icon;
  final bool isDarkTheme;

  /// Opens the screen behind this report; shows a chevron when set.
  final VoidCallback? onTap;

  const WidgetRecentActivity({
    super.key,
    required this.title,
    required this.subtitle,
    this.statusText,
    this.statusColor,
    required this.color,
    required this.icon,
    required this.isDarkTheme,
    this.onTap,
  });

  /// The canonical flat card — the same surface the dashboard shimmers use.
  static BoxDecoration decoration(bool isDark) => BoxDecoration(
    color: isDark ? Colors.grey[850] : Colors.white,
    borderRadius: BorderRadius.circular(AppRadius.defaultRadius),
    border: Border.all(
      color: isDark ? Colors.grey[850]! : Colors.grey[200]!,
      width: 0.5,
    ),
    boxShadow: const [AppShadows.cardShadow],
  );

  @override
  Widget build(BuildContext context) {
    final card = Container(
      decoration: decoration(isDarkTheme),
      padding: const EdgeInsets.all(15),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: color.withValues(alpha: isDarkTheme ? 0.22 : 0.12),
              borderRadius: BorderRadius.circular(AppRadius.defaultRadius),
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
                    fontSize: 15,
                    fontWeight: FontWeight.w600,
                    letterSpacing: 0,
                    color: isDarkTheme ? Colors.white : Colors.black87,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 4),
                Text(
                  subtitle,
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w400,
                    letterSpacing: 0,
                    color: isDarkTheme ? Colors.grey[400] : Colors.grey[600],
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
          const SizedBox(width: 10),
          if (statusText != null && statusText!.isNotEmpty)
            StatusColors.buildStatusBadge(
              statusText!,
              color: statusColor ?? StatusColors.grey,
              isDark: isDarkTheme,
            ),
          if (onTap != null)
            Padding(
              padding: const EdgeInsets.only(top: 10),
              child: Icon(
                Icons.chevron_right_rounded,
                size: 20,
                color: isDarkTheme ? Colors.white54 : AppColors.color6A7282,
              ),
            ),
        ],
      ),
    );
    if (onTap == null) return card;
    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: card,
    );
  }
}
