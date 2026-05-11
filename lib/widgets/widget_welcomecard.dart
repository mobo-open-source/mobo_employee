import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:mobo_employees/core/const/all_design.dart';
import 'package:mobo_employees/features/employee/dashboard/provider/dashboard_provider.dart';

class WelcomeCard extends StatelessWidget {
  final String wishText;
  final String subText;
  final double wishTextFontSize;
  final double subTextFontSize;
  final DashboardProvider provider;
  final bool isDarkTheme;

  const WelcomeCard({
    super.key,
    required this.wishText,
    required this.subText,
    required this.wishTextFontSize,
    required this.subTextFontSize,
    required this.provider,
    required this.isDarkTheme,
  });

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.of(context).size;

    return Card(
      color: AppColors.appColor,
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: EdgeInsets.symmetric(
          vertical: size.height * 0.03,
          horizontal: size.width * 0.04,
        ),
        child: Row(
          children: [
            Expanded(
              child: DefaultTextStyle(
                style: const TextStyle(color: Colors.white),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      wishText,
                      style: TextStyle(
                        fontSize: wishTextFontSize,
                        fontWeight: FontWeight.w700,
                      ),
                      overflow: TextOverflow.ellipsis,
                    ),
                    SizedBox(height: size.height * 0.005),
                    Text(
                      subText,
                      style: GoogleFonts.manrope(
                        fontSize: subTextFontSize,
                        fontWeight: FontWeight.w400,
                      ),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(width: 10),
            CircleAvatar(
              radius: 27,
              backgroundColor: Colors.white.withOpacity(.3),
              child:
                  provider.userImageBytes != null &&
                      provider.userImageBytes!.isNotEmpty
                  ? ClipOval(
                      child: Image.memory(
                        provider.userImageBytes!,
                        fit: BoxFit.cover,
                        width: double.infinity,
                        height: double.infinity,
                        errorBuilder: (context, error, stackTrace) {
                          return provider.iconHandle(
                            color: isDarkTheme ? Colors.white : Colors.white,
                          );
                        },
                      ),
                    )
                  : const Icon(Icons.person, color: Colors.black),
            ),
          ],
        ),
      ),
    );
  }
}
