import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:hugeicons/hugeicons.dart';
import 'package:mobo_employees/core/const/all_design.dart';
import 'package:mobo_employees/core/theme/app_theme.dart';

/// One employee in the manager's Employees list.
///
/// Laid out as the Figma frame (measured off its export): a 52px avatar at the
/// top left, 20px to its left the name (with the job-title badge on the same
/// line, at the right) and the phone and email under it, in 12px lines 3px
/// apart; 12px in from the sides and 16px above and below, which makes the
/// card the 91px the design shows. The surface is the canonical flat card —
/// the same as mobo CRM's customer list.
class WidgetEmployeeCard extends StatelessWidget {
  final Widget? child;
  final String? employeeName;
  final String? employeeJob;
  final String? employeePhone;
  final String? employeeEmail;

  const WidgetEmployeeCard({
    super.key,
    required this.child,
    required this.employeeName,
    required this.employeeJob,
    required this.employeePhone,
    required this.employeeEmail,
  });

  /// Edge of the avatar. The page sizes the image it passes in to this.
  static const double avatarSize = 52;

  /// Inset of the content from the card's edges — 12 at the sides, 16 above
  /// and below (plus the 0.5px of the card's border, which a bordered
  /// Container adds, as mobo CRM's card does). The loading placeholder uses it
  /// too, so the two don't jump.
  static const EdgeInsets padding = EdgeInsets.fromLTRB(12, 16, 12, 16);

  /// Between the avatar and the text beside it.
  static const double avatarGap = 20;

  /// Between the lines of the text column.
  static const double lineGap = 3;

  /// The card surface (§8), shared with the loading placeholder.
  static BoxDecoration decoration(bool isDark) => BoxDecoration(
    color: isDark ? Colors.grey[850] : Colors.white,
    borderRadius: BorderRadius.circular(AppRadius.defaultRadius),
    border: Border.all(
      color: isDark ? Colors.grey[850]! : Colors.grey[200]!,
      width: 0.5,
    ),
    boxShadow: const [AppShadows.cardShadow],
  );

  /// The job-title badge's colour: blue for a developer ("Developer",
  /// "Experienced Developer", …), green for every other title.
  static Color jobColor(String? job) =>
      (job ?? '').toLowerCase().contains('developer')
      ? AppColors.Color0095FF
      : AppColors.color65BA68;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final detailColor = isDark ? Colors.white70 : AppColors.color6A7282;
    final badgeColor = jobColor(employeeJob);

    Widget detail(List<List<dynamic>> icon, String text) => Row(
      children: [
        HugeIcon(icon: icon, size: 12, color: detailColor),
        const SizedBox(width: 6),
        Expanded(
          child: Text(
            text,
            style: GoogleFonts.manrope(
              fontSize: 12,
              fontWeight: FontWeight.w400,
              color: detailColor,
            ),
            overflow: TextOverflow.ellipsis,
          ),
        ),
      ],
    );

    return Container(
      padding: padding,
      decoration: decoration(isDark),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          ClipRRect(borderRadius: BorderRadius.circular(10), child: child),
          const SizedBox(width: avatarGap),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        employeeName.toString(),
                        style: GoogleFonts.manrope(
                          fontSize: 15,
                          fontWeight: FontWeight.w600,
                          color: AppColors.colorD14D72,
                        ),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    const SizedBox(width: 8),
                    // Capped so a long title shortens instead of overflowing.
                    ConstrainedBox(
                      constraints: const BoxConstraints(maxWidth: 140),
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 2,
                        ),
                        decoration: BoxDecoration(
                          color: badgeColor.withValues(alpha: 0.12),
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: Text(
                          employeeJob.toString(),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            fontSize: 11,
                            color: badgeColor,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: lineGap),
                detail(HugeIcons.strokeRoundedCall02, employeePhone.toString()),
                const SizedBox(height: lineGap),
                detail(HugeIcons.strokeRoundedMail01, employeeEmail.toString()),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
