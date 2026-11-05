import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:loading_animation_widget/loading_animation_widget.dart';
import 'package:mobo_employees/core/const/all_design.dart';
import 'package:mobo_employees/core/theme/app_theme.dart';

/// The one action of a create-form bottom sheet: a full-width brand button,
/// 52 tall with 16px bold text (it was a 48px half-width button sharing the
/// row with Cancel; the sheet's × now does Cancel's job).
class SheetSubmitButton extends StatelessWidget {
  final String label;

  /// Shown beside the progress dots while [isLoading]; the dots alone when null.
  final String? loadingLabel;
  final bool isLoading;

  /// Whether the form is complete enough to submit. An inactive button turns
  /// grey; a loading one keeps its brand colour behind the dots.
  final bool enabled;
  final VoidCallback? onPressed;
  final bool isDark;

  const SheetSubmitButton({
    super.key,
    required this.label,
    required this.enabled,
    required this.isLoading,
    required this.onPressed,
    required this.isDark,
    this.loadingLabel,
  });

  static const double height = 52;
  static const double radius = 12;

  @override
  Widget build(BuildContext context) {
    final dots = LoadingAnimationWidget.staggeredDotsWave(
      color: AppColors.whiteColor,
      size: 22,
    );

    return SizedBox(
      width: double.infinity,
      height: height,
      child: ElevatedButton(
        onPressed: enabled && !isLoading ? onPressed : null,
        style: ElevatedButton.styleFrom(
          backgroundColor: AppColors.colorC03355,
          foregroundColor: Colors.white,
          // Submitting keeps the brand colour behind the progress dots; only
          // an inactive button (a required field still empty) turns grey.
          disabledBackgroundColor: isLoading
              ? AppColors.colorC03355
              : AppTheme.disabledButtonFillFor(isDark),
          disabledForegroundColor: AppTheme.disabledButtonText,
          elevation: 0,
          shadowColor: Colors.transparent,
          padding: const EdgeInsets.symmetric(horizontal: 16),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(radius),
          ),
        ),
        child: isLoading
            ? Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  if (loadingLabel != null) ...[
                    Flexible(
                      child: Text(
                        loadingLabel!,
                        overflow: TextOverflow.ellipsis,
                        style: GoogleFonts.manrope(
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                          color: Colors.white,
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                  ],
                  dots,
                ],
              )
            : Text(
                label,
                style: GoogleFonts.manrope(
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                  color: Colors.white,
                ),
              ),
      ),
    );
  }
}
