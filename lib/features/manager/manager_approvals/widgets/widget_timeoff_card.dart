import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import 'package:mobo_employees/core/const/all_design.dart';
import 'package:mobo_employees/core/theme/app_theme.dart';

/// One request on the Approvals page's Time Off and Allocation tabs.
///
/// Laid out as the reference card (measured off it, in dp for a 358 wide card):
/// 12 of padding all round, a 40 circular photo, and beside it two lines — the
/// name with the status pill at the right of it, and under that the leave type,
/// the duration (bold) and the dates, with an allocation's balance at the right
/// of the same line. Under them the reason across the full width, and then two
/// equal buttons, Refuse and Approve/Validate, 31 tall.
class WidgetTimeOffCard extends StatelessWidget {
  final String employeeName;
  final String leaveType;

  /// How long, e.g. "2 days" — set bold in the line of details.
  final String duration;

  /// When, e.g. "10-12 Nov" (see [dateLabel]); none for an allocation.
  final String? date;

  /// An allocation's remaining / total, e.g. "(5.0/10.0)", at the right of the
  /// line of details; none for a time off.
  final String? balance;
  final String reason;
  final String status;

  /// Odoo `state` of the request (`confirm`, `validate1`, `validate`,
  /// `refuse`, `cancel` …) — colours the [status] pill.
  final String state;
  final bool statesss;
  final Uint8List? imageBytes;
  final VoidCallback? onValidate;
  final VoidCallback? onRefuse;
  final bool isValidating;
  final bool isRefusing;
  final String actionName;

  const WidgetTimeOffCard({
    super.key,
    required this.employeeName,
    required this.leaveType,
    required this.duration,
    required this.reason,
    required this.status,
    required this.state,
    required this.statesss,
    required this.imageBytes,
    required this.isValidating,
    required this.isRefusing,
    required this.actionName,
    this.date,
    this.balance,
    this.onValidate,
    this.onRefuse,
  });

  /// Inset of the content, the same on every side.
  static const double padding = 12;

  /// The photo's diameter. The two lines beside it share its height: the name
  /// at the top of it, the details at the bottom.
  static const double avatarSize = 40;

  /// Between the photo and the text beside it.
  static const double avatarGap = 12;

  /// Corner radius of the card: the default 12, as the Employees cards.
  static const double radius = AppRadius.defaultRadius;

  /// The card surface — the same flat card as the Employees list (white, a
  /// hairline border and the standard card shadow), shared with the loading
  /// placeholder.
  static BoxDecoration decoration(bool isDark) =>
      AppTheme.flatCardDecoration(isDark);

  /// The lists of these cards (Time Off, Allocation): the side inset sits in
  /// the list's own padding — not outside it — so the card shadow isn't clipped
  /// at the list's edges, and the gap between cards is the Employees list's 12.
  static const double listSideInset = 15;
  static const double listGap = 12;

  /// The list's padding: the side inset, a little room above the first card and
  /// [bottom] under the last.
  static EdgeInsets listPadding({double bottom = 12}) =>
      EdgeInsets.fromLTRB(listSideInset, 12, listSideInset, bottom);

  /// Size of the employee's name: the Employees card's 15, now larger than the
  /// reason (13) beneath it.
  static const double nameFontSize = 15;

  /// Size of the "Reason: …" line — it was 11, which read small under the name.
  static const double reasonFontSize = 13;

  /// Between the photo row and the reason, and between the reason and the
  /// buttons.
  static const double reasonGap = 4;
  static const double buttonsGap = 8;

  static const double buttonHeight = 31;
  static const double buttonRadius = 9;
  static const double buttonSpacing = 8;

  /// "10 Nov" for [from]..[to], in the shortest form that still reads
  /// unambiguously: "10-12 Nov" within a month, "28 Nov - 2 Dec" across months,
  /// the years only when they differ. Falls back to [fallback] when either end
  /// is unknown.
  static String dateLabel(
    DateTime? from,
    DateTime? to, {
    String fallback = '',
  }) {
    if (from == null || to == null) return fallback;
    final dayMonth = DateFormat('d MMM');
    final full = DateFormat('d MMM yyyy');
    if (DateUtils.isSameDay(from, to)) return dayMonth.format(from);
    if (from.year == to.year && from.month == to.month) {
      return '${from.day}-${dayMonth.format(to)}';
    }
    if (from.year == to.year) {
      return '${dayMonth.format(from)} - ${dayMonth.format(to)}';
    }
    return '${full.format(from)} - ${full.format(to)}';
  }

  /// An allocation's balance as the card shows it: "(5.0/10.0)".
  static String balanceLabel(double remaining, double total) =>
      '(${remaining.toStringAsFixed(1)}/${total.toStringAsFixed(1)})';

  /// A request waiting for approval: the pale blue pill of the reference.
  static bool _isPending(String state) =>
      state == 'confirm' || state == 'validate1';

  /// The status pill's fill and text. Pending is the reference's pale blue with
  /// dark blue text; every other state is its semantic colour on a tint of
  /// itself; dark mode keeps the app's translucent-white pill.
  static ({Color fill, Color text}) pillColors(String state, bool isDark) {
    if (isDark) {
      return (fill: Colors.white.withValues(alpha: 0.15), text: Colors.white);
    }
    if (_isPending(state)) {
      return (fill: const Color(0xFFDAEEFE), text: const Color(0xFF0E5794));
    }
    final color = StatusColors.forState(state);
    return (fill: color.withValues(alpha: 0.12), text: color);
  }

  /// The tan of an allocation's balance, in the reference.
  static const Color _balanceLight = Color(0xFF8F693B);
  static const Color _balanceDark = Color(0xFFD9A867);

  @override
  Widget build(BuildContext context) {
    final lowerCaseStatus = status.toLowerCase();
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final titleColor = isDark ? Colors.white : AppColors.color000000;
    final detailColor = isDark ? Colors.white70 : AppColors.color6A7282;

    final showActions =
        !statesss &&
        lowerCaseStatus != 'approved' &&
        lowerCaseStatus != 'refused';
    final showRefuse =
        showActions &&
        (lowerCaseStatus == 'approved' ||
            lowerCaseStatus == 'to approve' ||
            lowerCaseStatus == 'confirm' ||
            lowerCaseStatus == 'second approval');
    final showValidate =
        showActions &&
        (lowerCaseStatus == 'to approve' ||
            lowerCaseStatus == 'confirm' ||
            lowerCaseStatus == 'second approval' ||
            lowerCaseStatus == 'refused' ||
            lowerCaseStatus == 'cancelled');
    final hasButtons = showRefuse || showValidate;

    final pill = pillColors(state, isDark);

    // The leave type, the duration (bold) and the dates, one line.
    final details = Text.rich(
      TextSpan(
        style: GoogleFonts.manrope(
          fontSize: 11,
          fontWeight: FontWeight.w400,
          color: detailColor,
        ),
        children: [
          TextSpan(text: leaveType),
          const TextSpan(text: ' · '),
          TextSpan(
            text: duration,
            style: GoogleFonts.manrope(
              fontSize: 11,
              fontWeight: FontWeight.w700,
              color: titleColor,
            ),
          ),
          if (date != null && date!.isNotEmpty) TextSpan(text: ' · $date'),
        ],
      ),
      maxLines: 1,
      overflow: TextOverflow.ellipsis,
    );

    return Container(
      padding: const EdgeInsets.all(padding),
      decoration: decoration(isDark),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _profileImage(imageBytes: imageBytes, isDark: isDark),
              const SizedBox(width: avatarGap),
              Expanded(
                // As tall as the photo: the name (and the pill) at its top,
                // the details at its bottom.
                child: SizedBox(
                  height: avatarSize,
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Expanded(
                            child: Text(
                              employeeName,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: GoogleFonts.poppins(
                                fontSize: nameFontSize,
                                fontWeight: FontWeight.w600,
                                height: 1.4,
                                color: titleColor,
                              ),
                            ),
                          ),
                          const SizedBox(width: 8),
                          _pill(pill),
                        ],
                      ),
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.end,
                        children: [
                          Expanded(child: details),
                          if (balance != null) ...[
                            const SizedBox(width: 8),
                            Text(
                              balance!,
                              maxLines: 1,
                              style: GoogleFonts.manrope(
                                fontSize: 10,
                                fontWeight: FontWeight.w500,
                                color: isDark ? _balanceDark : _balanceLight,
                              ),
                            ),
                          ],
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),

          if (reason.isNotEmpty) ...[
            const SizedBox(height: reasonGap),
            Text.rich(
              TextSpan(
                children: [
                  const TextSpan(text: 'Reason: '),
                  TextSpan(text: reason),
                ],
              ),
              // Semi-bold, and as large as the name above it: at w400 and 11 the
              // line was too light and small to read beside the bold duration.
              style: GoogleFonts.manrope(
                fontSize: reasonFontSize,
                fontWeight: FontWeight.w600,
                color: titleColor,
              ),
            ),
          ],

          if (hasButtons) ...[
            SizedBox(height: reason.isNotEmpty ? buttonsGap : buttonsGap + 2),
            Row(
              children: [
                if (showRefuse)
                  Expanded(
                    child: _actionButton(
                      label: 'Refuse',
                      filled: false,
                      busy: isRefusing,
                      onPressed: isRefusing ? null : onRefuse,
                    ),
                  ),
                if (showRefuse && showValidate)
                  const SizedBox(width: buttonSpacing),
                if (showValidate)
                  Expanded(
                    child: _actionButton(
                      label: actionName,
                      filled: true,
                      busy: isValidating,
                      onPressed: isValidating ? null : onValidate,
                    ),
                  ),
              ],
            ),
          ],
        ],
      ),
    );
  }

  /// The status pill: small, with the status in it.
  Widget _pill(({Color fill, Color text}) colors) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      decoration: BoxDecoration(
        color: colors.fill,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(
        status,
        maxLines: 1,
        style: GoogleFonts.manrope(
          fontSize: 10,
          fontWeight: FontWeight.w700,
          color: colors.text,
        ),
      ),
    );
  }

  /// Refuse (outlined) or Validate (filled): 31 tall, 9 radius, bold labels.
  Widget _actionButton({
    required String label,
    required bool filled,
    required bool busy,
    required VoidCallback? onPressed,
  }) {
    final shape = RoundedRectangleBorder(
      borderRadius: BorderRadius.circular(buttonRadius),
    );
    const padding = EdgeInsets.symmetric(horizontal: 8);
    final labelStyle = GoogleFonts.poppins(
      fontSize: 12,
      fontWeight: filled ? FontWeight.w700 : FontWeight.w600,
      color: filled ? Colors.white : AppColors.colorC03355,
    );
    final child = busy
        ? SizedBox(
            height: 14,
            width: 14,
            child: CircularProgressIndicator(
              strokeWidth: 2,
              color: filled ? Colors.white : AppColors.colorC03355,
            ),
          )
        : Text(label, maxLines: 1, style: labelStyle);

    return SizedBox(
      height: buttonHeight,
      child: filled
          ? ElevatedButton(
              onPressed: onPressed,
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.colorC03355,
                padding: padding,
                minimumSize: const Size(0, buttonHeight),
                tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                shape: shape,
                elevation: 0,
                shadowColor: Colors.transparent,
              ),
              child: child,
            )
          : OutlinedButton(
              onPressed: onPressed,
              style: OutlinedButton.styleFrom(
                side: BorderSide(color: AppColors.colorC03355, width: 1),
                padding: padding,
                minimumSize: const Size(0, buttonHeight),
                tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                shape: shape,
              ),
              child: child,
            ),
    );
  }

  /// The employee's photo, round; a grey person while there is none.
  Widget _profileImage({required Uint8List? imageBytes, required bool isDark}) {
    final fallback = Center(
      child: Icon(
        Icons.person,
        size: 22,
        color: isDark ? Colors.white : AppColors.color000000,
      ),
    );
    return Container(
      width: avatarSize,
      height: avatarSize,
      clipBehavior: Clip.antiAlias,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: isDark ? Colors.grey[700] : AppColors.colorEDEDEB,
      ),
      child: imageBytes != null
          ? Image.memory(
              imageBytes,
              fit: BoxFit.cover,
              errorBuilder: (_, __, ___) => fallback,
            )
          : fallback,
    );
  }
}
