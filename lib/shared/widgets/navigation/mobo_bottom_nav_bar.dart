import 'package:flutter/material.dart';
import 'package:flutter_snake_navigationbar/flutter_snake_navigationbar.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:mobo_employees/core/const/all_design.dart';

/// The app's bottom navigation bar, shared by the employee and the manager
/// shells (they used to carry a copy each): a pinned Snake bar with the brand
/// indicator and the selected tab in the brand colour.
///
/// The selected tab is the Mobo brand colour in dark mode as well — as in the
/// inventory and CRM apps — rather than white, so the icon, its label and the
/// indicator above it read as one.
class MoboBottomNavBar extends StatelessWidget {
  final int currentIndex;
  final ValueChanged<int> onTap;
  final List<BottomNavigationBarItem> items;

  const MoboBottomNavBar({
    super.key,
    required this.currentIndex,
    required this.onTap,
    required this.items,
  });

  /// Height of the bar.
  static const double height = 70;

  /// The selected tab's icon and label: the brand colour, in both themes.
  static Color selectedColor(bool isDark) => AppColors.appColor;

  /// The other tabs.
  static Color unselectedColor(bool isDark) =>
      isDark ? AppColors.grey50 : AppColors.blackColor;

  static Color backgroundColor(bool isDark) =>
      isDark ? AppColors.greyShade900Color : AppColors.whiteColor;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return SnakeNavigationBar.color(
      backgroundColor: backgroundColor(isDark),
      unselectedItemColor: unselectedColor(isDark),
      selectedItemColor: selectedColor(isDark),
      snakeViewColor: AppColors.appColor,
      showSelectedLabels: true,
      showUnselectedLabels: true,
      currentIndex: currentIndex,
      onTap: onTap,
      snakeShape: SnakeShape.indicator,
      height: height,
      elevation: 8,
      shadowColor: isDark ? Colors.black26 : Colors.grey[200]!,
      selectedLabelStyle: GoogleFonts.montserrat(
        fontSize: 12,
        fontWeight: FontWeight.w600,
      ),
      unselectedLabelStyle: GoogleFonts.montserrat(
        fontSize: 11,
        fontWeight: FontWeight.w500,
      ),
      items: items,
    );
  }
}
