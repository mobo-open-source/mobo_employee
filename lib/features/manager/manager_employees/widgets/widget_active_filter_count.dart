import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:mobo_employees/core/const/all_design.dart';
import 'package:mobo_employees/features/manager/manager_employees/provider/manager_employees_provider.dart';

Widget ActiveFilterCount(ManagerEmployeesProvider provider, bool isDarkTheme) {
  if (provider.activeFilters.isEmpty) {
    /// No filters → plain text
    return Text(
      provider.filterLabel,
      style: GoogleFonts.manrope(
        color: AppColors.color4A5565,
        fontSize: 14,
        fontWeight: FontWeight.w400,
      ),
    );
  }

  /// Filters applied → container pill
  return Container(
    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
    decoration: BoxDecoration(
      color: isDarkTheme
          ? AppColors.whiteColor.withOpacity(.2)
          : AppColors.color000000,
      borderRadius: BorderRadius.circular(5),
      border: Border.all(color: AppColors.whiteColor.withOpacity(.3)),
    ),
    child: Text(
      provider.filterLabel,

      style: GoogleFonts.manrope(
        color: AppColors.whiteColor,
        fontSize: 12,
        fontWeight: FontWeight.w400,
        letterSpacing: 0,
      ),
    ),
  );
}
