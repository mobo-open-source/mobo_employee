import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:mobo_employees/core/const/all_design.dart';

class CommonFilterTile extends StatelessWidget {
  final String title;
  final bool selected;
  final VoidCallback onTap;
  final Color primaryColor;

  const CommonFilterTile({
    super.key,
    required this.title,
    required this.selected,
    required this.onTap,
    this.primaryColor = AppColors.appColor,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        margin: const EdgeInsets.only(bottom: 10),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        decoration: BoxDecoration(
          color: selected
              ? AppColors.appColor
              : AppColors.appColor.withOpacity(.1),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Text(
          title,
          style: GoogleFonts.manrope(
            fontSize: 14,
            color: selected ? Colors.white : Colors.black87,
          ),
        ),
      ),
    );
  }
}
