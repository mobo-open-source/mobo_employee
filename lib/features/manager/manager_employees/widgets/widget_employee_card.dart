import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:hugeicons/hugeicons.dart';
import 'package:mobo_employees/core/const/all_design.dart';
import 'package:mobo_employees/core/theme/app_theme.dart';

/// One employee in the manager's Employees list.
///
/// Laid out as the Figma frame: the avatar at the top left, 20px to its left
/// the name (with the job-title badge on the same line, at the right) and the
/// phone and email under it, in 16px lines 3px apart; 12px in from the sides
/// and 16px above and below, which makes the card the 91px the design shows.
/// The avatar is as tall as that text block, so its top and bottom line up with
/// the name and the email. The surface is the canonical flat card — the same as
/// mobo CRM's customer list.
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

  /// Height of the name line (the job-title badge sits on it).
  static const double nameLineHeight = 20;

  /// Height of the phone line and of the email line.
  static const double detailLineHeight = 16;

  /// Between the lines of the text column.
  static const double lineGap = 3;

  /// The text column's height: the name, then the phone and the email, each in
  /// a line box of fixed height — so it is the same whatever the font's own
  /// line metrics, and the avatar can be sized to it.
  static const double textBlockHeight =
      nameLineHeight + lineGap + detailLineHeight + lineGap + detailLineHeight;

  /// Edge of the avatar: as tall as the text beside it, so the image runs from
  /// the name down to the email. The page sizes the image it passes in to this.
  static const double avatarSize = textBlockHeight;

  /// Inset of the content from the card's edges — 12 at the sides, 16 above
  /// and below (plus the 0.5px of the card's border, which a bordered
  /// Container adds, as mobo CRM's card does). The loading placeholder uses it
  /// too, so the two don't jump.
  static const EdgeInsets padding = EdgeInsets.fromLTRB(12, 16, 12, 16);

  /// Between the avatar and the text beside it.
  static const double avatarGap = 20;

  /// The card surface (§8), shared with the loading placeholder — and with the
  /// Approvals cards: see [AppTheme.flatCardDecoration].
  static BoxDecoration decoration(bool isDark) =>
      AppTheme.flatCardDecoration(isDark);

  /// The job-title badge's colour: blue for a developer ("Developer",
  /// "Experienced Developer", …), green for every other title.
  static Color jobColor(String? job) =>
      (job ?? '').toLowerCase().contains('developer')
      ? AppColors.Color0095FF
      : AppColors.color65BA68;

  /// The role pill's fill and text, as the status pills of the Approvals cards:
  /// a pale tint with *dark* text of the same hue (a developer's dark blue, any
  /// other role's dark green) — rather than the bright hue itself, which was
  /// too light to read as bold text. Dark mode is the translucent-white pill.
  static ({Color fill, Color text}) rolePillColors(String? job, bool isDark) {
    if (isDark) {
      return (fill: Colors.white.withValues(alpha: 0.15), text: Colors.white);
    }
    return jobColor(job) == AppColors.Color0095FF
        ? (fill: const Color(0xFFDAEEFE), text: const Color(0xFF0E5794))
        : (fill: const Color(0xFFE3F2E3), text: const Color(0xFF186C1B));
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final detailColor = isDark ? Colors.white70 : AppColors.color6A7282;
    final rolePill = rolePillColors(employeeJob, isDark);

    Widget detail(List<List<dynamic>> icon, String text) => SizedBox(
      height: detailLineHeight,
      child: Row(
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
      ),
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
              // Only as tall as its three lines: a Column in a Row fills any
              // bounded height it is given, which is not the card's to take.
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                SizedBox(
                  height: nameLineHeight,
                  child: Row(
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
                            color: rolePill.fill,
                            borderRadius: BorderRadius.circular(20),
                          ),
                          child: Text(
                            employeeJob.toString(),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            // Bold and dark, like a status on the Approvals cards.
                            style: GoogleFonts.manrope(
                              fontSize: 11,
                              color: rolePill.text,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
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
