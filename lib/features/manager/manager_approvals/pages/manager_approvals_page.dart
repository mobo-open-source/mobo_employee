import 'package:flutter/material.dart';
import 'package:mobo_employees/features/manager/manager_approvals/providers/manager_approvals_provider.dart';
import 'package:mobo_employees/features/manager/manager_approvals/widgets/widget_activity_tab_selection.dart';
import 'package:mobo_employees/features/manager/manager_approvals/widgets/page_index_click.dart';
import 'package:mobo_employees/features/manager/manager_approvals/widgets/widget_manager_speed_dial.dart';
import 'package:provider/provider.dart';

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
      context
          .read<ManagerApprovalsProvider>()
          .loadInitialData();
    });
  }

  @override
  Widget build(BuildContext context) {
    final isDarkTheme = Theme.of(context).brightness == Brightness.dark;
    return Consumer<ManagerApprovalsProvider>(
      builder: (context, provider, _) {
        return Scaffold(
          floatingActionButton: provider.selectedTabIndex == 1
              ? const WidgetManagerSpeedDial()
              : const SizedBox.shrink(),
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
                  padding: const EdgeInsets.symmetric(horizontal: 15),
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
