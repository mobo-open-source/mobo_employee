import 'package:flutter/material.dart';
import 'package:hugeicons/hugeicons.dart';
import 'package:mobo_employees/core/theme/app_theme.dart';

/// One attendance record as a card, in the style of mobo Sales' quotation /
/// invoice list cards: the employee in the brand colour with the day under it
/// in grey, a status badge on the right, the check-in and check-out as
/// icon-led info lines, and the worked hours as a label/value row at the
/// bottom.
///
/// Shown inside a group once a Group By is applied (the ungrouped list is a
/// table). It takes plain strings — the page formats them — so it carries no
/// provider.
class AttendanceCard extends StatelessWidget {
  final String employee;

  /// The day of the check-in, e.g. "Nov 05, 2026".
  final String date;
  final String checkIn;
  final String checkOut;

  /// The check-out's day (e.g. "Nov 06"), only for a shift that ended on a
  /// later day than it began.
  final String? checkOutDate;
  final String worked;

  /// No check-out yet — still on the clock.
  final bool isCheckedIn;

  const AttendanceCard({
    super.key,
    required this.employee,
    required this.date,
    required this.checkIn,
    required this.checkOut,
    required this.worked,
    required this.isCheckedIn,
    this.checkOutDate,
  });

  /// Sales' secondary text and info-icon greys.
  static const Color _meta = Color(0xFF6D717F);
  static const Color _metaIcon = Color(0xFFC5C5C5);

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final infoStyle = TextStyle(
      fontSize: 12,
      fontWeight: FontWeight.w400,
      letterSpacing: 0,
      color: isDark ? Colors.grey[100] : _meta,
    );

    Widget info(List<List<dynamic>> icon, String text) => Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        HugeIcon(
          icon: icon,
          size: 14,
          color: isDark ? Colors.grey[100]! : _metaIcon,
        ),
        const SizedBox(width: 6),
        Flexible(
          child: Text(text, style: infoStyle, overflow: TextOverflow.ellipsis),
        ),
      ],
    );

    final checkOutText = checkOutDate == null
        ? 'Check Out: $checkOut'
        : 'Check Out: $checkOut ($checkOutDate)';

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: isDark ? Colors.grey[850] : Colors.white,
        borderRadius: BorderRadius.circular(AppRadius.defaultRadius),
        border: Border.all(
          color: isDark ? Colors.grey[850]! : Colors.grey[200]!,
          width: 0.5,
        ),
        boxShadow: const [AppShadows.cardShadow],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SizedBox(height: 4),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      employee,
                      style: TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w600,
                        letterSpacing: -0.1,
                        color: isDark ? Colors.white : AppTheme.primaryColor,
                      ),
                      overflow: TextOverflow.ellipsis,
                    ),
                    Padding(
                      padding: const EdgeInsets.only(top: 2),
                      child: Text(
                        date,
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w400,
                          letterSpacing: 0,
                          color: isDark ? Colors.grey[300] : _meta,
                        ),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),

              /// Still on the clock is in progress (blue); a closed
              /// attendance is done (green).
              StatusColors.buildStatusBadge(
                isCheckedIn ? 'Checked In' : 'Checked Out',
                color: isCheckedIn ? StatusColors.blue : StatusColors.green,
                isDark: isDark,
              ),
            ],
          ),
          Padding(
            padding: const EdgeInsets.only(top: 4),
            child: Wrap(
              spacing: 12,
              runSpacing: 6,
              crossAxisAlignment: WrapCrossAlignment.center,
              children: [
                info(HugeIcons.strokeRoundedLogin01, 'Check In: $checkIn'),
                info(HugeIcons.strokeRoundedLogout01, checkOutText),
              ],
            ),
          ),
          const SizedBox(height: 8),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: Text(
                  'Worked Hours',
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w500,
                    color: isDark ? Colors.grey[200] : const Color(0xFF5E5E5E),
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              Text(
                worked,
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w700,
                  color: isDark ? Colors.white : const Color(0xFF101010),
                ),
              ),
            ],
          ),
          const SizedBox(height: 4),
        ],
      ),
    );
  }
}
