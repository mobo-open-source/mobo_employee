import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

class AppTheme {
  static const Color primaryColor = Color(0xFFC03355);
  static const Color secondaryColor = Color(0xFFffffff);

  // --- Base palette (Mobo UI Style Guide §1) ------------------------------
  static const Color dark = Color(0xFF101010);
  static const Color white = Color(0xFFFFFFFF);
  static const Color lightGrey = Color(0xFFF3F3F3);
  static const Color background = lightGrey;
  static const Color scaffoldBackground = Color(0xFFFAFAFA);
  static const Color textPrimary = dark;
  static const Color textSecondary = Color(0xFF666666);
  static const Color divider = Color(0xFFE0E0E0);
  static const Color shadow = Color(0x1A000000);
  static const Color darkScaffold = Color(0xFF181A20);
  static const Color darkSurface = Color(0xFF1E1E1E);

  static Color labelColor(bool isDark) => isDark ? Colors.white : dark;
  static Color secondaryLabelColor(bool isDark) =>
      isDark ? Colors.grey[400]! : Colors.grey[600]!;

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
    scaffoldBackgroundColor: scaffoldBackground,
    appBarTheme: const AppBarTheme(
      backgroundColor: primaryColor,
      foregroundColor: Colors.white,
      elevation: 0,
    ),
    elevatedButtonTheme: ElevatedButtonThemeData(
      style: ElevatedButton.styleFrom(
        elevation: 0,
        shadowColor: Colors.transparent,
        backgroundColor: primaryColor,
        foregroundColor: Colors.white,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppRadius.defaultRadius),
        ),
      ),
    ),
    inputDecorationTheme: InputDecorationTheme(
      border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: primaryColor, width: 2),
      ),
    ),
    popupMenuTheme: const PopupMenuThemeData(
      color: Colors.white,
      surfaceTintColor: Colors.transparent,
      elevation: 4,
    ),
    /// Override the M3 default pale tonal header with the brand color.
    datePickerTheme: DatePickerThemeData(
      backgroundColor: Colors.white,
      headerBackgroundColor: primaryColor,
      headerForegroundColor: Colors.white,
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
    scaffoldBackgroundColor: darkScaffold,
    appBarTheme: const AppBarTheme(
      backgroundColor: primaryColor,
      foregroundColor: Colors.white,
      elevation: 0,
    ),
    elevatedButtonTheme: ElevatedButtonThemeData(
      style: ElevatedButton.styleFrom(
        elevation: 0,
        shadowColor: Colors.transparent,
        backgroundColor: primaryColor,
        foregroundColor: Colors.white,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppRadius.defaultRadius),
        ),
      ),
    ),
    inputDecorationTheme: InputDecorationTheme(
      border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: primaryColor, width: 2),
      ),
    ),
    popupMenuTheme: const PopupMenuThemeData(
      color: Color(0xFF2C2C2E),
      surfaceTintColor: Colors.transparent,
      elevation: 4,
    ),
    /// Same header override as the light theme.
    datePickerTheme: DatePickerThemeData(
      backgroundColor: Colors.grey[900],
      headerBackgroundColor: primaryColor,
      headerForegroundColor: Colors.white,
    ),

    /// Apply the custom TextTheme
    textTheme: _buildTextTheme(TextTheme()),
  );
}

/// Semantic/status colors (Mobo UI Style Guide §1). Use these for every
/// status/stage indicator instead of reaching for a raw Material color.
class StatusColors {
  const StatusColors._();

  /// approved, done, posted, won, paid, planned
  static const Color green = Color(0xFF00A63E);

  /// sent, qualified, in-progress/proposal
  static const Color blue = Color(0xFF3B82F6);

  /// draft
  static const Color orange = Color(0xFFF97316);

  /// cancelled, lost
  static const Color red = Color(0xFFEF4444);

  /// locked/done (secondary "complete" state)
  static const Color teal = Color(0xFF14B8A6);

  /// unknown/default fallback
  static const Color grey = Color(0xFF6B7280);

  /// Maps a status string (case-insensitive) to its semantic color. Falls
  /// back to [grey] for anything unrecognised rather than guessing.
  static Color forState(String? state) {
    switch (state?.toLowerCase().trim()) {
      case 'approved':
      case 'done':
      case 'posted':
      case 'won':
      case 'paid':
      case 'planned':
      case 'confirmed':
      case 'checked_in':
      case 'checked_out':
      case 'present':
        return green;
      case 'sent':
      case 'qualified':
      case 'in_progress':
      case 'in-progress':
      case 'proposal':
      case 'pending':
        return blue;
      case 'draft':
        return orange;
      case 'cancelled':
      case 'canceled':
      case 'lost':
      case 'rejected':
      case 'absent':
        return red;
      case 'locked':
        return teal;
      default:
        return grey;
    }
  }

  /// Canonical status-badge formula (§10) built from a semantic color.
  static Widget buildStatusBadge(
    String label, {
    required Color color,
    required bool isDark,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: isDark ? Colors.white.withValues(alpha: 0.15) : color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(18),
      ),
      child: Text(
        label,
        style: TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.w600,
          color: isDark ? Colors.white : color,
          letterSpacing: 0.1,
        ),
      ),
    );
  }
}

/// Elevation/shadow tokens (§3). Depth comes only from these explicit
/// `BoxShadow`s, never from Material `elevation`.
class AppShadows {
  const AppShadows._();

  /// Standard "flat card" shadow — list items, list-style cards, form cards.
  static const cardShadow = BoxShadow(
    color: Color(0x0D000000), // black @ 5%
    offset: Offset(0, 6),
    blurRadius: 16,
    spreadRadius: 2,
  );

  /// "Panel" shadow — bigger surfaces like chart containers, dashboard
  /// sections.
  static BoxShadow panelShadow(bool isDark) => BoxShadow(
        color: isDark ? Colors.black26 : Colors.black.withValues(alpha: 0.08),
        blurRadius: 12,
        offset: const Offset(0, 4),
      );

  /// Soft shadow for pill-shaped search bars only.
  static const searchShadow = BoxShadow(
    color: Color(0x0A000000), // black @ 4%
    offset: Offset(3, 11),
    blurRadius: 8.5,
    spreadRadius: -3,
  );
}

/// Spacing/radius scale (§4). Default to [defaultRadius] when unsure.
class AppRadius {
  const AppRadius._();

  static const double chip = 4;
  static const double compactDropdown = 5;
  static const double segmentChip = 6;
  static const double control = 8;
  static const double segmentedSelector = 10;

  /// Default radius — cards, list tiles, buttons, text fields, tag chips.
  static const double defaultRadius = 12;

  /// Kanban column, bottom sheet top corners, panel/section container.
  static const double panel = 16;

  /// Canonical status badge.
  static const double statusBadge = 18;

  /// Pill buttons/chips, multi-select chip, dialog radius.
  static const double pill = 20;

  /// Tall/full bottom sheet variant (rare).
  static const double tallSheet = 28;
}
