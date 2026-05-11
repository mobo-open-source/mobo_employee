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
    final size = MediaQuery.of(context).size;

    return Consumer<DashboardProvider>(
      builder: (context, provider, _) {
        return Container(
          decoration: BoxDecoration(
            color: Colors.white,
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
          child: Padding(
            padding: EdgeInsets.symmetric(
              vertical: size.height * 0.022,
              horizontal: size.width * 0.04,
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                Expanded(
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.center,
                    children: [
                      Container(
                        height: 44,
                        width: 44,
                        alignment: Alignment.center,
                        decoration: BoxDecoration(
                          color: AppColors.ColorB7B7B7.withOpacity(.19),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: HugeIcon(
                          icon: HugeIcons.strokeRoundedCheckmarkCircle04,
                          size: 22,
                          color: AppColors.color000000,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              text,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              subtext,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                fontSize: 14,
                                fontWeight: FontWeight.w600,
                                color: color,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
                SizedBox(
                  width: 140,
                  child: provider.isCheckInOutLoading
                      ? const Center(
                          child: SizedBox(
                            height: 22,
                            width: 22,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          ),
                        )
                      : provider.isAttendanceCheckedIn
                      ? _checkOutButton(provider, context)
                      : _checkInButton(provider, context),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _checkInButton(DashboardProvider provider, context) {
    return SizedBox(
      height: 40,
      child: ElevatedButton.icon(
        onPressed: () {
          provider.performCheckIn(context: context);
        },
        icon: const HugeIcon(
          icon: HugeIcons.strokeRoundedLogoutSquare01,
          size: 18,
        ),
        label: const Text("Check In"),
        style: ElevatedButton.styleFrom(
          backgroundColor: AppColors.color000000,
          foregroundColor: Colors.white,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(10),
          ),
        ),
      ),
    );
  }

  Widget _checkOutButton(DashboardProvider provider, context) {
    return SizedBox(
      height: 40,
      child: OutlinedButton.icon(
        onPressed: () {
          provider.performCheckOut(context: context);
        },
        icon: const HugeIcon(
          icon: HugeIcons.strokeRoundedLoginSquare02,
          size: 18,
        ),
        label: const Text("Check Out"),
        style: OutlinedButton.styleFrom(
          foregroundColor: AppColors.color000000,
          side: BorderSide(color: AppColors.color000000),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(10),
          ),
        ),
      ),
    );
  }
}
