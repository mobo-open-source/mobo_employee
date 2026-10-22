import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:mobo_employees/core/const/all_design.dart';
import 'package:mobo_employees/shared/widgets/avatars/initials_avatar.dart';

class WidgetManagerWelcomeCard extends StatelessWidget {
  final String wishText;
  final String subText;
  final double wishTextFontSize;
  final double subTextFontSize;
  final Uint8List? userAvatar;
  final String? userName;
  final bool isDarkTheme;

  const WidgetManagerWelcomeCard({
    super.key,
    required this.wishText,
    required this.subText,
    required this.wishTextFontSize,
    required this.subTextFontSize,
    required this.userAvatar,
    required this.userName,
    required this.isDarkTheme,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(10),
        color: AppColors.appColor,
      ),
      padding: const EdgeInsets.all(24),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  wishText,
                  style: GoogleFonts.manrope(
                    color: Colors.white,
                    fontSize: wishTextFontSize,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 0.5,
                    height: 1.2,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  subText,
                  style: GoogleFonts.manrope(
                    color: Colors.white.withOpacity(0.9),
                    fontSize: subTextFontSize,
                    fontWeight: FontWeight.w400,
                    letterSpacing: 0,
                    height: 1.3,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 10),
          Container(
            width: 60,
            height: 60,
            padding: const EdgeInsets.all(2),
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: Colors.white,
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.1),
                  blurRadius: 8,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            child: userAvatar != null && userAvatar!.isNotEmpty
                ? ClipOval(
                    child: Image.memory(
                      userAvatar!,
                      fit: BoxFit.cover,
                      width: double.infinity,
                      height: double.infinity,
                      errorBuilder: (context, error, stackTrace) =>
                          InitialsAvatar(name: userName, diameter: 56),
                    ),
                  )
                : InitialsAvatar(name: userName, diameter: 56),
          ),
        ],
      ),
    );
  }
}
