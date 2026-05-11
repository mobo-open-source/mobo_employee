import 'package:flutter/material.dart';
import 'package:lottie/lottie.dart';
import 'package:mobo_employees/core/const/all_design.dart';
import 'package:mobo_employees/features/manager/manager_approvals/providers/manager_approvals_provider.dart';
import 'package:mobo_employees/features/manager/manager_approvals/widgets/app_shimmer.dart';
import 'package:mobo_employees/features/manager/manager_approvals/widgets/widget_timeoff_card.dart';
import 'package:provider/provider.dart';

class WidgetManagerAllocationViewPage extends StatelessWidget {
  const WidgetManagerAllocationViewPage({super.key});

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<ManagerApprovalsProvider>();
    if (provider.isAllocationLoading) {
      return ListView.separated(
        padding: const EdgeInsets.symmetric(vertical: 12),
        itemCount: 6,
        separatorBuilder: (_, __) => const SizedBox(height: 10),
        itemBuilder: (_, __) => const WidgetTimeOffCardShimmer(),
      );
    }

    if (provider.allocationList.isEmpty) {
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
                    child: Lottie.asset('assets/lotties/empty ghost.json'),
                  ),
                  const SizedBox(height: 10),
                  Text(
                    "No Allocation Records Found",
                    style: TextStyle(
                      fontSize: 18,
                      color: AppColors.blackColor,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
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
      itemCount: provider.allocationList.length,
      itemBuilder: (context, index) {
        final item = provider.allocationList[index];
        final imageBytes = provider.getEmployeeImage(item.employeeId);
        if (imageBytes == null) {
          Future.microtask(() async {
            await provider.loadEmployeeImage(item.employeeId);
          });
        }

        final isValidating = provider.isValidating(item.id);
        final isRefusing = provider.isRefusing(item.id);

        return WidgetTimeOffCard(
          employeeName: item.employeeName,
          leaveType: item.leaveTypeName,

          dateRange:
              "${item.durationDisplay} • Remaining: ${item.remainingLeaves}/${item.maxLeaves}",

          reason: item.notes.isNotEmpty ? item.notes : "",

          status: item.state == 'validate'
              ? 'Approved'
              : item.state == 'refuse'
              ? 'Refused'
              : 'To Approve',

          actionName: "Validate",

          statesss: item.state == 'validate',

          imageBytes: imageBytes,

          onValidate: isValidating
              ? null
              : () => provider.validateAllocation(context, item.id),

          onRefuse: isRefusing
              ? null
              : () => provider.refuseAllocation(context, item.id),

            isValidating: isValidating,
          isRefusing: isRefusing,
        );
      },
    );
  }
}
