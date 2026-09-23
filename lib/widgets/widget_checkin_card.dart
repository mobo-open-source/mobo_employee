import 'package:flutter/material.dart';
import 'package:hugeicons/hugeicons.dart';
import 'package:mobo_employees/core/const/all_design.dart';
import 'package:mobo_employees/features/employee/dashboard/provider/dashboard_provider.dart';
import 'package:provider/provider.dart';

class WidgetCheckInCard extends StatelessWidget {
  final bool isDarkTheme;
  final String text;
  final String subtext;
  final Color color;

  const WidgetCheckInCard({
    super.key,
    required this.isDarkTheme,
    required this.text,
    required this.subtext,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Consumer<DashboardProvider>(
      builder: (context, provider, _) {
        return Container(
          width: double.infinity,
          padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 16),
          decoration: BoxDecoration(
            color: isDarkTheme ? AppColors.greyShade800Color : Colors.white,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: isDarkTheme
                  ? AppColors.greyShade700Color
                  : const Color(0xFFE0E0E0),
            ),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(isDarkTheme ? 0.25 : 0.06),
                blurRadius: 12,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(11),
                decoration: BoxDecoration(
                  color: isDarkTheme
                      ? AppColors.greyShade700Color
                      : const Color(0xFFF4F4F4),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: HugeIcon(
                  icon: HugeIcons.strokeRoundedCheckmarkCircle04,
                  size: 22,
                  color: isDarkTheme
                      ? Colors.grey.shade400
                      : Colors.grey.shade600,
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      text,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w700,
                        letterSpacing: 0.1,
                        color: isDarkTheme ? Colors.white : Colors.black87,
                      ),
                    ),
                    const SizedBox(height: 3),
                    Text(
                      subtext,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w500,
                        color: Colors.grey.shade500,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 10),
              provider.isCheckInOutLoading
                  ? const SizedBox(
                      width: 68,
                      child: Center(
                        child: SizedBox(
                          height: 16,
                          width: 16,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        ),
                      ),
                    )
                  : provider.isAttendanceCheckedIn
                  ? _checkOutButton(provider, context)
                  : _checkInButton(provider, context),
            ],
          ),
        );
      },
    );
  }

  Widget _checkInButton(DashboardProvider provider, BuildContext context) {
    return GestureDetector(
      onTap: () => provider.performCheckIn(context: context),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        curve: Curves.easeInOut,
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 11),
        decoration: BoxDecoration(
          color: isDarkTheme ? Colors.white : AppColors.color000000,
          borderRadius: BorderRadius.circular(10),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            HugeIcon(
              icon: HugeIcons.strokeRoundedLogoutSquare01,
              size: 15,
              color: isDarkTheme ? Colors.black87 : Colors.white,
            ),
            const SizedBox(width: 7),
            Text(
              "Check In",
              style: TextStyle(
                fontWeight: FontWeight.w600,
                fontSize: 13,
                letterSpacing: 0.1,
                color: isDarkTheme ? Colors.black87 : Colors.white,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _checkOutButton(DashboardProvider provider, BuildContext context) {
    final textColor = isDarkTheme ? Colors.white : Colors.black87;
    return GestureDetector(
      onTap: () => provider.performCheckOut(context: context),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        curve: Curves.easeInOut,
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 11),
        decoration: BoxDecoration(
          color: Colors.transparent,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: textColor, width: 0.5),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            HugeIcon(
              icon: HugeIcons.strokeRoundedLoginSquare02,
              size: 15,
              color: textColor,
            ),
            const SizedBox(width: 7),
            Text(
              "Check Out",
              style: TextStyle(
                fontWeight: FontWeight.w600,
                fontSize: 13,
                letterSpacing: 0.1,
                color: textColor,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
