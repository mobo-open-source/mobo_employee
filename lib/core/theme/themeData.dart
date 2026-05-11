import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

class AppTheme {
  static const Color primaryColor = Color(0xFFC03355);
  static const Color secondaryColor = Color(0xFFffffff);

  /// Define a custom TextTheme using Manrope font for all text styles
  static TextTheme _buildTextTheme(TextTheme base) {
    return base.copyWith(
      /// Display styles
      displayLarge: GoogleFonts.qahiri(textStyle: base.displayLarge),
      displayMedium: GoogleFonts.qahiri(textStyle: base.displayMedium),
      displaySmall: GoogleFonts.qahiri(textStyle: base.displaySmall),

      /// Headline styles
      headlineLarge: GoogleFonts.manrope(textStyle: base.headlineLarge),
      headlineMedium: GoogleFonts.manrope(textStyle: base.headlineMedium),
      headlineSmall: GoogleFonts.manrope(textStyle: base.headlineSmall),

      /// Title styles
      titleLarge: GoogleFonts.manrope(textStyle: base.titleLarge),
      titleMedium: GoogleFonts.manrope(textStyle: base.titleMedium),
      titleSmall: GoogleFonts.manrope(textStyle: base.titleSmall),

      /// Body text styles
      bodyLarge: GoogleFonts.manrope(textStyle: base.bodyLarge),
      bodyMedium: GoogleFonts.manrope(textStyle: base.bodyMedium),
      bodySmall: GoogleFonts.manrope(textStyle: base.bodySmall),

      /// Label styles
      labelLarge: GoogleFonts.manrope(textStyle: base.labelLarge),
      labelMedium: GoogleFonts.manrope(textStyle: base.labelMedium),
      labelSmall: GoogleFonts.manrope(textStyle: base.labelSmall),
    );
  }

  static ThemeData lightTheme = ThemeData(
    brightness: Brightness.light,
    primaryColor: primaryColor,
    fontFamily: GoogleFonts.manrope().fontFamily,
    colorScheme: ColorScheme.fromSeed(
      seedColor: primaryColor,
      brightness: Brightness.light,
      primary: primaryColor,
      secondary: secondaryColor,
    ),
    scaffoldBackgroundColor: Colors.grey.shade50,
    appBarTheme: const AppBarTheme(
      backgroundColor: primaryColor,
      foregroundColor: Colors.white,
      elevation: 0,
    ),
    elevatedButtonTheme: ElevatedButtonThemeData(
      style: ElevatedButton.styleFrom(
        backgroundColor: primaryColor,
        foregroundColor: Colors.white,
      ),
    ),
    inputDecorationTheme: InputDecorationTheme(
      border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: primaryColor, width: 2),
      ),
    ),
    primaryTextTheme: _buildTextTheme(TextTheme()),
    textTheme: _buildTextTheme(TextTheme()),
  );

  static ThemeData darkTheme = ThemeData(
    brightness: Brightness.dark,
    primaryColor: primaryColor,
    fontFamily: GoogleFonts.manrope().fontFamily,
    colorScheme: ColorScheme.fromSeed(
      seedColor: primaryColor,
      brightness: Brightness.dark,
      primary: primaryColor,
      secondary: secondaryColor,
    ),
    scaffoldBackgroundColor: Colors.grey[900],
    appBarTheme: const AppBarTheme(
      backgroundColor: primaryColor,
      foregroundColor: Colors.white,
      elevation: 0,
    ),
    elevatedButtonTheme: ElevatedButtonThemeData(
      style: ElevatedButton.styleFrom(
        backgroundColor: primaryColor,
        foregroundColor: Colors.white,
      ),
    ),
    inputDecorationTheme: InputDecorationTheme(
      border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: primaryColor, width: 2),
      ),
    ),

    /// Apply the custom TextTheme
    textTheme: _buildTextTheme(TextTheme()),
  );
}
