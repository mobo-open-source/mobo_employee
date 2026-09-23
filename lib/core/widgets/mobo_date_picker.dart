import 'package:flutter/material.dart';
import 'package:mobo_employees/core/const/all_design.dart';

/// Themed wrapper around [showDatePicker] so every date picker in the app
/// uses the same primary colour (header, selection, today border).
class MoboDatePicker {
  static Future<DateTime?> show({
    required BuildContext context,
    DateTime? initialDate,
    DateTime? firstDate,
    DateTime? lastDate,
    String? helpText,
  }) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    const primary = AppColors.appColor;

    return showDatePicker(
      context: context,
      initialDate: initialDate ?? DateTime.now(),
      firstDate: firstDate ?? DateTime(2000),
      lastDate: lastDate ?? DateTime(2100),
      helpText: helpText,
      builder: (context, child) {
        final base = Theme.of(context);
        return Theme(
          data: base.copyWith(
            colorScheme: base.colorScheme.copyWith(
              primary: primary,
              onPrimary: Colors.white,
              surface: isDark ? AppColors.cardDark : Colors.white,
              onSurface: isDark ? Colors.white : Colors.black,
            ),
            datePickerTheme: DatePickerThemeData(
              backgroundColor: isDark ? AppColors.cardDark : Colors.white,
              headerBackgroundColor: primary,
              headerForegroundColor: Colors.white,
              dayBackgroundColor: WidgetStateProperty.resolveWith((states) {
                if (states.contains(WidgetState.selected)) return primary;
                return Colors.transparent;
              }),
              dayForegroundColor: WidgetStateProperty.resolveWith((states) {
                if (states.contains(WidgetState.selected)) return Colors.white;
                return isDark ? Colors.white : Colors.black;
              }),
              todayBorder: const BorderSide(color: primary, width: 1),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
              ),
            ),
            textButtonTheme: TextButtonThemeData(
              style: TextButton.styleFrom(foregroundColor: primary),
            ),
          ),
          child: child!,
        );
      },
    );
  }
}
