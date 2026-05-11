import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:mobo_employees/core/const/all_design.dart';

class WidgetFilterTile extends StatelessWidget {
  final String title;
  final String? subtitle;
  final bool isSelected;
  final Widget? trailing;
  final VoidCallback onTap;

  const WidgetFilterTile({
    super.key,
    required this.title,
    required this.onTap,
    this.subtitle,
    this.isSelected = false,
    this.trailing,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      borderRadius: BorderRadius.circular(8),
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 12),
        child: Row(
          children: [
            /// Leading icon
            Icon(
              isSelected ? Icons.check_circle : Icons.radio_button_unchecked,
              size: 18,
              color: isSelected ? AppColors.colorE53E5A : AppColors.color4A5565,
            ),

            const SizedBox(width: 10),

            /// Title + Subtitle
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: GoogleFonts.manrope(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  if (subtitle != null)
                    Padding(
                      padding: const EdgeInsets.only(top: 2),
                      child: Text(
                        subtitle!,
                        style: GoogleFonts.manrope(
                          fontSize: 11,
                          color: AppColors.color4A5565,
                        ),
                      ),
                    ),
                ],
              ),
            ),

            /// Optional trailing widget
            if (trailing != null) trailing!,
          ],
        ),
      ),
    );
  }
}

