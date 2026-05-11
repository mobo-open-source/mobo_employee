import 'package:flutter/material.dart';
import 'package:hugeicons/hugeicons.dart';
import 'package:mobo_employees/core/const/all_design.dart';
import 'package:mobo_employees/features/employee/dashboard/provider/dashboard_provider.dart';
import 'package:provider/provider.dart';

class WidgetAttendanceCheckoutCard extends StatelessWidget {
  const WidgetAttendanceCheckoutCard({super.key});

  @override
  Widget build(BuildContext context) {
    return Consumer<DashboardProvider>(
      builder: (context, provider, _) {


        return Container(
          decoration: BoxDecoration(
            color: AppColors.whiteColor,
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
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
            child: Row(
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
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        provider.isAttendanceCheckedIn
                            ? "Currently working"
                            : "Not Checked In",
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        provider.getWorkedDuration().isNotEmpty
                            ? provider.getWorkedDuration()
                            : "00:00",
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                          color: AppColors.colorC03355,
                        ),
                      ),
                    ],
                  ),
                ),

                provider.isCheckInOutLoading
                    ? SizedBox(
                        height: 22,
                        width: 22,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : provider.isAttendanceCheckedIn
                    ?
                      SizedBox(
                        height: 40,
                        child: OutlinedButton.icon(
                          onPressed: () =>
                              provider.performCheckOut(context: context),
                          icon: const Icon(Icons.logout),
                          label: const Text(
                            "Check Out",
                            style: TextStyle(fontWeight: FontWeight.w700),
                          ),
                          style: OutlinedButton.styleFrom(
                            foregroundColor: AppColors.color000000,
                            side: BorderSide(color: AppColors.color000000),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(10),
                            ),
                          ),
                        ),
                      )
                    : SizedBox(
                        height: 40,
                        child: ElevatedButton.icon(
                          onPressed: () {
                            provider.performCheckIn(context: context);
                          },
                          icon: const Icon(Icons.login),
                          label: const Text("Check In"),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: AppColors.color000000,
                            foregroundColor: Colors.white,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(10),
                            ),
                          ),
                        ),
                      ),
              ],
            ),
          ),
        );
      },
    );
  }
}
