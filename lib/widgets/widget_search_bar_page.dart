import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:hugeicons/hugeicons.dart';
import 'package:mobo_employees/core/const/all_design.dart';

class WidgetSearchBarPage extends StatelessWidget {
  final List<List<dynamic>>? leftIcon;
  final List<List<dynamic>> rightIcon;
  final double iconSize;
  final Color iconColor;
  final TextEditingController controller;
  final dynamic provider;
  final bool isDarkTheme;
  final String hintText;
  final VoidCallback? onTap;
  final VoidCallback? clearfield;

  const WidgetSearchBarPage({
    super.key,
    this.leftIcon,
    required this.rightIcon,
    required this.iconSize,
    required this.iconColor,
    required this.controller,
    required this.provider,
    required this.isDarkTheme,
    required this.hintText,
    this.onTap,
    this.clearfield,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: AppColors.color000000.withOpacity(.04),
            offset: const Offset(3, 11),
            blurRadius: 8.5,
            spreadRadius: -3,
          ),
        ],
      ),
      child: TextFormField(
        controller: controller,
        onChanged: (value) {
          provider.updateSearch(value);
        },
        decoration: InputDecoration(
          filled: true,
          fillColor: isDarkTheme ? AppColors.greyShade800Color : Colors.white,

          /// Prefix Icon
          prefixIcon: leftIcon == null
              ? null
              : Material(
                  color: Colors.transparent,
                  child: InkWell(
                    borderRadius: BorderRadius.circular(12),
                    onTap: onTap,
                    child: Padding(
                      padding: const EdgeInsets.all(12),
                      child: HugeIcon(
                        icon: leftIcon!,
                        size: iconSize,
                        color: iconColor,
                      ),
                    ),
                  ),
                ),

          /// Clear Icon
          suffixIcon: controller.text.isNotEmpty
              ? Material(
                  color: Colors.transparent,
                  child: InkWell(
                    borderRadius: BorderRadius.circular(12),
                    onTap: clearfield,
                    child: Padding(
                      padding: const EdgeInsets.all(12),
                      child: HugeIcon(
                        icon: rightIcon,
                        size: iconSize,
                        color: iconColor,
                      ),
                    ),
                  ),
                )
              : const SizedBox.shrink(),

          hintText: hintText,
          hintStyle: GoogleFonts.manrope(
            fontSize: 14,
            color: isDarkTheme ? AppColors.whiteColor : AppColors.color4A5565,
            fontWeight: FontWeight.w400,
          ),
          isDense: true,
          contentPadding: const EdgeInsets.symmetric(vertical: 12),
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: BorderSide.none,
          ),
        ),
      ),
    );
  }
}
