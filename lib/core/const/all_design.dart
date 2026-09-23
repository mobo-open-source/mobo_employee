import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../theme/themeData.dart';

class AppColors {
  static const Color appColor = AppTheme.primaryColor;
  static const Color whiteColor = AppTheme.secondaryColor;
  static const Color blackColor = Colors.black;

  static const Color primaryTint = Color(0xFFFCE7EE);
  static const Color surfaceLight = Color(0xFFFFFFFF);
  static const Color elevatedDark = Color(0xFF424242);
  static const Color textPrimary = Color(0xFF101010);
  static const Color textHint = Color(0xFF939BA6);
  static const Color searchDark = Color(0xFF2A2A2A);
  static const Color cardDark = Color(0xFF303030);
  static const Color inputFillLight = Color(0xFFF2F4F6);
  static const Color inputFillDark = Color(0xFF2C2C2C);
  static const Color popupDark = Color(0xFF2C2C2C);
  static const Color error = Color(0xFFF44336);

  static Color inputFill(bool isDark) => isDark ? inputFillDark : inputFillLight;

  static Color white = Colors.white;

  static Color grey = Colors.grey;
  static Color grey50 = Colors.grey.shade50;
  static Color greyShade100Color = Colors.grey.shade100;
  static Color greyShade300Color = Colors.grey.shade300;
  static Color greyShade400Color = Colors.grey.shade400;
  static Color greyShade500Color = Colors.grey.shade500;
  static Color greyShade600Color = Colors.grey.shade600;
  static Color greyShade700Color = Colors.grey.shade700;
  static Color greyShade800Color = Colors.grey.shade800;
  static Color greyShade900Color = Colors.grey.shade900;

  static Color yellow500 = Colors.yellow.shade500;

  static Color red = Colors.red;
  static Color red50 = Colors.red.shade50;
  static Color red500 = Colors.red.shade500;

  static Color black12 = Colors.black12;
  static Color black26 = Colors.black26;
  static Color black54 = Colors.black54;

  static Color green = Colors.green;
  static Color green50 = Colors.green.shade50;
  static Color green600 = Colors.green.shade600;

  static Color blue = Colors.blue;
  static Color blue50 = Colors.blue.shade50;

  static Color ColorB7B7B7 = Color(0xFFB7B7B7);
  static Color Color0095FF = Color(0xFF0095FF);
  static Color Color43B75D = Color(0xFF43B75D);
  static Color Color9C27B0 = Color(0xFF9C27B0);
  static Color ColorFF9800 = Color(0xFFFF9800);
  static Color colorC03355 = Color(0xFFC03355);
  static Color Color009688 = Color(0xFF009688);
  static Color Color616161 = Color(0xFF616161);

  static Color color000000 = Color(0xFF000000);
  static Color Color3F3F3F = Color(0xFF3F3F3F);
  static Color Color4E4E4E = Color(0xFF4E4E4E);
  static Color Color00A63E = Color(0xFF00A63E);
  static Color colorFFAA00 = Color(0xFFFFAA00);
  static Color ColorF90000 = Color(0xFFF90000);
  static Color ColorD9D9D9 = Color(0xFFD9D9D9);
  static Color color6A7282 = Color(0xFF6A7282);
  static Color color101828 = Color(0xFF101828);
  static Color colorF09DA9 = Color(0xFFF09DA9);
  static Color colorF59E0B = Color(0xFFF59E0B);
  static Color color43B75D = Color(0xFF43B75D);
  static Color colorE5E5E5 = Color(0xFFE5E5E5);
  static Color colorF9EAED = Color(0xFFF9EAED);
  static Color colorF8F9FA = Color(0xFFF8F9FA);
  static Color colorB3B3B3 = Color(0xFFB3B3B3);
  static Color colorFFCC00 = Color(0xFFFFCC00);
  static Color color009688 = Color(0xFF009688);
  static Color color007AFF = Color(0xFF007AFF);
  static Color colorF30B0B = Color(0xFFF30B0B);
  static Color color666666 = Color(0xFF666666);
  static Color color4A5565 = Color(0xFF4A5565);
  static Color colorFFFFFF = Color(0xFFFFFFFF);
  static Color colorE5E7EB = Color(0xFFE5E7EB);
  static Color color364153 = Color(0xFF364153);
  static Color colorE53E5A = Color(0xFFE53E5A);
  static Color colorBDBDBD = Color(0xFFBDBDBD);
  static Color colorD14D72 = Color(0xFFD14D72);
  static Color color65BA68 = Color(0xFF65BA68);
  static Color colorEDEDEB = Color(0xFFEDEDEB);
  static Color colorFFCC3D = Color(0xFFFFCC3D);
  static Color color616161 = Color(0xFF616161);
  static Color colorF3F3F5 = Color(0xFFF3F3F5);
  static Color color6D717F = Color(0xFF6D717F);
  static Color colorF0F0F0 = Color(0xFFF0F0F0);
  static Color colorFF0700 = Color(0xFFFF0700);
  static Color color22C55E = Color(0xFF22C55E);
  static Color colorEEEEEE = Color(0xFFEEEEEE);
  static Color colorD1D5DC = Color(0xFFD1D5DC);
  static Color color2196F3 = Color(0xFF2196F3);
  static Color color339BC0 = Color(0xFF339BC0);
  static Color colorF9FAFB = Color(0xFFF9FAFB);

  static Color appColor2551925185 = Color.fromARGB(255, 192, 51, 85);
}

class AssetImageConvert {
  static const AssetImage loginBgImage = AssetImage("assets/bgImage.png");
  static const AssetImage carImage = AssetImage("assets/fleet_car.png");
  static const AssetImage bikeImage = AssetImage("assets/fleet_bike.png");
  static const AssetImage emptyImage = AssetImage("assets/empty.jpg");
}

TextStyle monserratGoogleStyle({
  required double? fontSize,
  required FontWeight fontWeight,
  required Color color,
  required double? letterSpacing,
}) {
  return GoogleFonts.montserrat(
    fontSize: fontSize,
    color: color,
    fontWeight: fontWeight,
    letterSpacing: letterSpacing,
  );
}

TextStyle myCustomStyle({
  required double? fontSize,
  required FontWeight fontWeight,
  required Color color,
  required double? letterSpacing,
}) {
  return TextStyle(
    fontFamily: 'MyCustomFont',
    fontSize: fontSize,
    color: color,
    fontWeight: fontWeight,
    letterSpacing: letterSpacing,
  );
}

void showSnackBarMessage({
  required BuildContext context,
  required String message,
  required Color backgroundColor,
}) {
  if (!context.mounted) return;

  ScaffoldMessenger.of(context).clearSnackBars();

  ScaffoldMessenger.of(context).showSnackBar(
    SnackBar(
      content: Text(message),
      backgroundColor: backgroundColor,
      duration: Duration(seconds: 2),
      behavior: SnackBarBehavior.floating,
      margin: const EdgeInsets.all(16),
    ),
  );
}

class ActivityTabs {
  static const int fuel = 0;
  static const int odometer = 1;
  static const int service = 2;
  static const int contract = 3;
}
