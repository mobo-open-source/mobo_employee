import 'package:flutter/material.dart';
import 'package:mobo_employees/core/const/all_design.dart';
import 'package:mobo_employees/features/manager/manager_approvals/providers/manager_approvals_provider.dart';
import 'package:mobo_employees/features/manager/manager_approvals/widgets/allocation_create_sheet.dart';
import 'package:mobo_employees/features/manager/manager_approvals/widgets/widget_activity_tab_selection.dart';
import 'package:mobo_employees/features/manager/manager_approvals/widgets/page_index_click.dart';
import 'package:mobo_employees/features/manager/manager_approvals/widgets/widget_manager_speed_dial.dart';
import 'package:provider/provider.dart';

import '../../../../widgets/snackbar_widgets.dart';

class ManagerApprovalsPage extends StatefulWidget {
  const ManagerApprovalsPage({super.key});

  @override
  State<ManagerApprovalsPage> createState() => _ManagerApprovalsPageState();
}

class _ManagerApprovalsPageState extends State<ManagerApprovalsPage> {
  @override
  void initState() {
    super.initState();

    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<ManagerApprovalsProvider>().loadInitialData();
    });
  }

  Future<void> _createAllocation(ManagerApprovalsProvider provider) async {
    final created = await AllocationCreateSheet.show(context);
    if (!created || !mounted) return;
    CustomSnackbar.showSuccess(context, "Allocation created");
    await provider.onAllocationCreated();
  }

  Widget _buildFab(ManagerApprovalsProvider provider) {
    if (provider.selectedTabIndex == 1) return const WidgetManagerSpeedDial();
    if (provider.selectedTabIndex == 2 && provider.canCreateAllocation) {
      return FloatingActionButton(
        tooltip: "New Allocation",
        backgroundColor: AppColors.appColor,
        foregroundColor: Colors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
        onPressed: () => _createAllocation(provider),
        child: const Icon(Icons.add),
      );
    }
    return const SizedBox.shrink();
  }

  @override
  Widget build(BuildContext context) {
    final isDarkTheme = Theme.of(context).brightness == Brightness.dark;
    return Consumer<ManagerApprovalsProvider>(
      builder: (context, provider, _) {
        return Scaffold(
          floatingActionButton: _buildFab(provider),
          body: Column(
            children: [
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 15),
                child: CommonActivityTabSelector(
                  tabs: const ["Calendar", "Time Off", "Allocation"],
                  selectedIndex: provider.selectedTabIndex,
                  isDarkTheme: isDarkTheme,
                  onChanged: provider.setTab,
                ),
              ),
              const SizedBox(height: 10),
              Expanded(
                child: Padding(
                  // The calendar sits in the page's 15px side inset. The Time
                  // Off and Allocation lists carry it in their own padding
                  // instead, so their cards' shadows aren't clipped at the edge.
                  padding: EdgeInsets.symmetric(
                    horizontal: provider.selectedTabIndex == 0 ? 15 : 0,
                  ),
                  child: buildSelectedView(provider.selectedTabIndex, context),
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}
