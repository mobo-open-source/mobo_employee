import 'package:flutter/material.dart';
import 'package:hugeicons/hugeicons.dart';
import 'package:mobo_employees/core/const/all_design.dart';
import 'package:mobo_employees/features/manager/manager_dashboard/provider/manager_dashboard_provider.dart';

class WidgetManagerWelcomeCard extends StatelessWidget {
  final String wishText;
  final String subText;
  final double wishTextFontSize;
  final double subTextFontSize;
  final ManagerDashboardProvider provider;
  final bool isDarkTheme;

  const WidgetManagerWelcomeCard({
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
                      style: TextStyle(
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
                          ///fallback when image decoding fails
                          return HugeIcon(
                            icon: HugeIcons.strokeRoundedUserCircle02,
                            size: 35,
                            color: Colors.white,
                          );
                        },
                      ),
                    )
                  : HugeIcon(
                      icon: HugeIcons.strokeRoundedUserCircle02,
                      size: 35,
                      color: Colors.white,
                    ),
            ),
          ],
        ),
      ),
    );
  }
}
