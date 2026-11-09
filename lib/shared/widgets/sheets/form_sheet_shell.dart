import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:hugeicons/hugeicons.dart';
import 'package:mobo_employees/core/const/all_design.dart';
import 'package:mobo_employees/core/theme/app_theme.dart';

/// The frame of a create form that opens over a screen — a bottom sheet (New
/// Allocation, Apply for Leave) or a centred popup (New Attendance): a heading
/// band with a subtle grey rule under it, the fields, and one full-width
/// action underneath, evenly spaced.
///
/// As the events app's form cards: the same 16px above and below the title,
/// the rule right beneath it and edge to edge, then 16px to the first field.
/// Under the fields the action has 20 of room above it and 20 below it — as it
/// has at its sides — so it sits in an evenly padded, aligned footer. As a
/// bottom sheet the system's bottom inset is added to that, so the action
/// clears a gesture bar.
///
/// As a sheet it lives inside `showModalBottomSheet(backgroundColor:
/// Colors.transparent)`: the surface and its rounded top corners are drawn
/// here. As a popup ([centered]) it lives inside `showDialog` and is a
/// [Dialog], rounded all round.
class FormSheetShell extends StatelessWidget {
  final String title;

  /// Closes the sheet; null disables the close button (while saving).
  final VoidCallback? onClose;

  /// The fields, top to bottom. Spacing between them is the caller's.
  final List<Widget> children;

  /// The action — a [SheetSubmitButton].
  final Widget footer;

  /// Shows the form as a popup in the middle of the screen instead of a sheet
  /// rising from the bottom.
  final bool centered;

  /// While true the fields and the action ignore input — for a form that is
  /// saving. Nothing is drawn over the form: its own [SheetSubmitButton] shows
  /// the progress, so the form stays put and in view until it closes.
  final bool locked;

  const FormSheetShell({
    super.key,
    required this.title,
    required this.onClose,
    required this.children,
    required this.footer,
    this.centered = false,
    this.locked = false,
  });

  /// Side inset shared by the heading, the fields and the footer.
  static const double inset = 20;

  /// Above the footer, and below it (before the system inset).
  static const double footerGap = 20;

  /// Corner radius of the popup (§19: dialogs are 20).
  static const double popupRadius = 20;

  /// Widest a popup gets, so it doesn't stretch across a tablet.
  static const double popupMaxWidth = 560;

  /// The rule under the heading: `grey.shade200`, `grey[700]` in dark mode —
  /// the events app's form card divider.
  static Color ruleColor(bool isDark) =>
      isDark ? Colors.grey.shade700 : Colors.grey.shade200;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final media = MediaQuery.of(context);
    final surface = isDark ? AppTheme.darkSurface : Colors.white;

    final frame = Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        /// ───── Heading band ─────
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: inset, vertical: 16),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: Text(
                  title,
                  style: GoogleFonts.manrope(
                    fontSize: 18,
                    fontWeight: FontWeight.w500,
                    color: isDark ? Colors.white : AppColors.color000000,
                  ),
                ),
              ),
              InkWell(
                onTap: onClose,
                child: Container(
                  padding: const EdgeInsets.all(6),
                  decoration: BoxDecoration(
                    color: isDark
                        ? AppColors.inputFillDark
                        : AppColors.colorF3F3F5,
                    shape: BoxShape.circle,
                  ),
                  child: HugeIcon(
                    icon: HugeIcons.strokeRoundedCancel01,
                    color: isDark ? Colors.white : AppColors.color000000,
                    size: 18,
                  ),
                ),
              ),
            ],
          ),
        ),
        Divider(height: 1, color: ruleColor(isDark)),

        /// ───── Fields and action ─────
        Padding(
          padding: EdgeInsets.fromLTRB(
            inset,
            16,
            inset,
            footerGap + (centered ? 0 : media.padding.bottom),
          ),
          child: IgnorePointer(
            ignoring: locked,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                ...children,
                const SizedBox(height: footerGap),
                footer,
              ],
            ),
          ),
        ),
      ],
    );

    if (centered) {
      return Dialog(
        backgroundColor: surface,
        elevation: 0,
        shadowColor: Colors.transparent,
        surfaceTintColor: Colors.transparent,
        insetPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
        clipBehavior: Clip.antiAlias,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(popupRadius),
        ),
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: popupMaxWidth),
          child: SingleChildScrollView(
            keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
            child: frame,
          ),
        ),
      );
    }

    return Padding(
      padding: EdgeInsets.only(bottom: media.viewInsets.bottom),
      child: SingleChildScrollView(
        keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
        child: Container(
          decoration: BoxDecoration(
            color: surface,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
          ),
          child: frame,
        ),
      ),
    );
  }
}
