import 'package:flutter/material.dart';
import 'package:mobo_employees/core/theme/app_theme.dart';
import 'package:mobo_employees/features/manager/manager_approvals/providers/manager_approvals_provider.dart';
import 'package:mobo_employees/features/manager/manager_approvals/widgets/widget_timeoff_card.dart';
import 'package:mobo_employees/shared/widgets/connection_status_widget.dart';
import 'package:mobo_employees/shared/widgets/empty_state.dart';
import 'package:mobo_employees/shared/widgets/loaders/loading_widget.dart';
import 'package:provider/provider.dart';

class WidgetManagerAllocationViewPage extends StatelessWidget {
  const WidgetManagerAllocationViewPage({super.key});

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<ManagerApprovalsProvider>();
    if (provider.allocationLoadError != null) {
      return ConnectionStatusWidget(
        error: provider.allocationLoadError,
        onRetry: provider.fetchAllocationDetails,
      );
    }
    // Only the very first read (or a retry after a failure) is "loading" — and
    // it is a small loader, not a list of shimmering cards. Every later read
    // happens in place under the list that is already on screen.
    if (provider.isAllocationLoading && provider.allocationList.isEmpty) {
      return const LoadingWidget(size: 44);
    }

    if (provider.allocationList.isEmpty) {
      return ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        children: [
          SizedBox(
            height: MediaQuery.of(context).size.height * 0.6,
            child: const Center(
              child: EmptyState(
                title: "No Allocation Records Found",
                lottieAsset: 'assets/lotties/empty ghost.json',
              ),
            ),
          ),
        ],
      );
    }

    return ListView.separated(
      // Room under the last card so it scrolls clear of the New Allocation
      // button, when it's shown.
      padding: WidgetTimeOffCard.listPadding(
        bottom: provider.canCreateAllocation ? AppSpacing.fabClearance : 12,
      ),
      separatorBuilder: (_, __) =>
          const SizedBox(height: WidgetTimeOffCard.listGap),
      itemCount: provider.allocationList.length,
      itemBuilder: (context, index) {
        final item = provider.allocationList[index];
        // Avatars are preloaded by fetchAllocationDetails(); don't fetch per-row here.
        final imageBytes = provider.getEmployeeImage(item.employeeId);

        final isValidating = provider.isValidating(item.id);
        final isRefusing = provider.isRefusing(item.id);

        return WidgetTimeOffCard(
          employeeName: item.employeeName,
          leaveType: item.leaveTypeName,

          duration: item.durationDisplay,
          // What is left of the allocation, out of what was given.
          balance: WidgetTimeOffCard.balanceLabel(
            item.remainingLeaves,
            item.maxLeaves,
          ),

          reason: item.notes.isNotEmpty ? item.notes : "",

          status: item.state == 'validate'
              ? 'Approved'
              : item.state == 'refuse'
              ? 'Refused'
              : 'To Approve',

          state: item.state,

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
