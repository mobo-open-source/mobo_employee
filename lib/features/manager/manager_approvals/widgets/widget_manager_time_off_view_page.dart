import 'package:flutter/material.dart';
import 'package:lottie/lottie.dart';
import 'package:mobo_employees/core/services/odoo_session_manager.dart';
import 'package:mobo_employees/core/const/all_design.dart';
import 'package:mobo_employees/features/manager/manager_approvals/providers/manager_approvals_provider.dart';
import 'package:mobo_employees/features/manager/manager_approvals/widgets/app_shimmer.dart';
import 'package:mobo_employees/features/manager/manager_approvals/widgets/widget_timeoff_card.dart';
import 'package:provider/provider.dart';

class WidgetManagerTimeOffViewPage extends StatelessWidget {
  const WidgetManagerTimeOffViewPage({super.key});

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<ManagerApprovalsProvider>();

    /// Initial load for TimeOff
    if (provider.isTimeOffLoading) {
      return ListView.separated(
        padding: const EdgeInsets.symmetric(vertical: 12),
        itemCount: 6,
        separatorBuilder: (_, __) => const SizedBox(height: 10),
        itemBuilder: (_, __) => const WidgetTimeOffCardShimmer(),
      );
    }

    if (provider.timeOffList.isEmpty) {
      return ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        children: [
          SizedBox(
            height: MediaQuery.of(context).size.height * 0.6,
            child: Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  SizedBox(
                    height: 120,
                    width: 120,
                    child: Lottie.asset(
                      'assets/lotties/empty ghost.json',
                      repeat: true,
                      animate: true,
                    ),
                  ),
                  const SizedBox(height: 10),
                  Text(
                    "No Timeoff Records Found",
                    style: TextStyle(
                      fontSize: 18,
                      color: AppColors.blackColor,
                      fontWeight: FontWeight.bold,
                      letterSpacing: 0,
                    ),
                  ),
                  const SizedBox(height: 10),
                ],
              ),
            ),
          ),
        ],
      );
    }

    return ListView.separated(
      padding: const EdgeInsets.symmetric(vertical: 12),
      separatorBuilder: (_, __) => const SizedBox(height: 10),
      itemCount: provider.timeOffList.length,
      itemBuilder: (context, index) {
        final item = provider.timeOffList[index];
         final imageBytes = provider.getEmployeeImage(item.employeeId);
        if (imageBytes == null) {
          Future.microtask(() {
            provider.loadEmployeeImage(item.employeeId);
          });
        }
        final bool isCancelled = item.state == 'cancel';
        final isValidating = provider.isValidating(item.id);
        final isRefusing = provider.isRefusing(item.id);
        final majorVersion = provider.serverMajorVersion ?? 19;
        final hideButtonsForV18 =
            majorVersion == 18 &&
            (item.state == "validate" || item.state == "refuse");
        return WidgetTimeOffCard(
          employeeName: item.employeeName.toString(),
          leaveType: item.leaveTypeName,
          statesss: item.state == 'cancel' || hideButtonsForV18,
          dateRange:
              "${item.dateFromFormatted} – ${item.dateToFormatted} . ${item.durationDisplay}",
          reason: item.description,
          status: item.state == 'cancel'
              ? 'Cancelled'
              : item.state == 'validate'
              ? 'Approved'
              : item.state == 'validate1'
              ? "Second Approval"
              : item.state == "refuse"
              ? "Refused"
              : 'To Approve',
          actionName: majorVersion == 19
              ? "Validate"
              : item.state == "validate1"
              ? "Validate"
              : "Approve",
          imageBytes: imageBytes,
          onValidate: isValidating
              ? null
              : () => provider.validateTimeOff(item.id, item.state),
          onRefuse: isRefusing ? null : () => provider.refuseTimeOff(item.id),
          isValidating: isValidating,
          isRefusing: isRefusing,
        );
      },
    );
  }
}
