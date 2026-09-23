import 'dart:typed_data';

import 'package:flutter/material.dart';
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
      child: Padding(
        padding: const EdgeInsets.only(
          left: 15,
          right: 15,
          top: 28,
          bottom: 28,
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Flexible(
              child: DefaultTextStyle(
                style: const TextStyle(color: Colors.white),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      wishText,
                      style: TextStyle(
                        fontSize: wishTextFontSize,
                        fontWeight: FontWeight.w600,
                      ),
                      overflow: TextOverflow.ellipsis,
                    ),
                    Text(
                      subText,
                      style: TextStyle(
                        fontSize: subTextFontSize,
                        fontWeight: FontWeight.w400,
                      ),
                      overflow: TextOverflow.visible,
                    ),
                  ],
                ),
              ),
            ),
            Container(
              width: 60,
              height: 60,
              padding: const EdgeInsets.all(2),
              decoration: const BoxDecoration(
                shape: BoxShape.circle,
                color: Colors.white,
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
      ),
    );
  }
}
