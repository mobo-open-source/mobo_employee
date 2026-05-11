import 'package:flutter/material.dart';
import 'package:hugeicons/hugeicons.dart';
import 'package:lottie/lottie.dart';
import 'package:mobo_employees/core/const/all_design.dart';
import 'package:mobo_employees/features/manager/manager_employees/provider/manager_employees_provider.dart';
import 'package:mobo_employees/features/manager/manager_employees/widgets/widget_active_filter_count.dart';
import 'package:mobo_employees/features/manager/manager_employees/widgets/widget_employee_card.dart';
import 'package:mobo_employees/features/manager/manager_employees/widgets/widget_employee_card_shimmer.dart';
import 'package:mobo_employees/features/manager/manager_employees/widgets/widget_employee_filter_bottomsheet.dart';
import 'package:mobo_employees/widgets/widget_search_bar_page.dart';
import 'package:provider/provider.dart';
import '../../../../shared/widgets/pagination/pagination_controls.dart';

class ManagerEmployeesPage extends StatefulWidget {
  const ManagerEmployeesPage({super.key});

  @override
  State<ManagerEmployeesPage> createState() => _ManagerEmployeesPageState();
}

class _ManagerEmployeesPageState extends State<ManagerEmployeesPage> {
  @override
  void initState() {
    super.initState();

    final provider = context.read<ManagerEmployeesProvider>();

    provider.searchEmployeeController.addListener(() {
      provider.updateSearch(provider.searchEmployeeController.text);
    });
    if (provider.initialLoading == false) {
      Future.microtask(provider.fetchEmployees);
      WidgetsBinding.instance.addPostFrameCallback((_) {
        provider.changeInitialLoading();
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDarkTheme = Theme.of(context).brightness == Brightness.dark;
    final provider = context.watch<ManagerEmployeesProvider>();

    return Scaffold(
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            WidgetSearchBarPage(
              leftIcon: HugeIcons.strokeRoundedFilterHorizontal,
              rightIcon: HugeIcons.strokeRoundedCancel01,
              iconSize: 20,
              onTap: () {
                final provider = context.read<ManagerEmployeesProvider>();
                provider.prepareDraftFilters();
                showModalBottomSheet(
                  context: context,
                  isScrollControlled: true,
                  builder: (_) {
                    return Consumer<ManagerEmployeesProvider>(
                      builder: (_, provider, __) {
                        return WidgetEmployeesFilterBottomSheet();
                      },
                    );
                  },
                );
              },
              clearfield: provider.clearSearch,
              iconColor: AppColors.color666666,
              controller: provider.searchEmployeeController,
              provider: provider,
              isDarkTheme: isDarkTheme,
              hintText: 'Search employees...',
            ),

            const SizedBox(height: 10),

            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                ActiveFilterCount(provider, isDarkTheme),
                Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    PaginationControls(
                      canGoToPreviousPage: provider.canGoPrevious,
                      canGoToNextPage: provider.canGoNext,
                      onPreviousPage: () => provider.previousPage(),
                      onNextPage: () => provider.nextPage(),
                      paginationText: provider.paginationText,
                      isDark: isDarkTheme,
                      theme: Theme.of(context),
                    ),
                  ],
                ),
              ],
            ),

            const SizedBox(height: 10),
            Expanded(
              child: provider.isLoading || provider.initialLoading == false
                  ? ListView.separated(
                      itemCount: 12, /// shimmer count
                      separatorBuilder: (_, __) => const SizedBox(height: 8),
                      itemBuilder: (_, __) => const WidgetEmployeeCardShimmer(),
                    )
                  : provider.employees.isEmpty
                  ? Center(
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
                            "No Employee Records Found",
                            style: TextStyle(
                              fontSize: 18,
                              color: AppColors.blackColor,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ],
                      ),
                    )
                  : RefreshIndicator(
                      onRefresh: provider.refreshEmployees,
                      child: ListView.separated(
                        itemCount: provider.employees.length,
                        separatorBuilder: (_, __) => const SizedBox(height: 8),
                        itemBuilder: (context, index) {
                          final employee = provider.employees[index];

                          return WidgetEmployeeCard(
                            employeeEmail: employee.workEmail ?? "-",
                            employeePhone: employee?.workPhone ?? "-",
                            employeeJob: employee.jobTitle ?? "-",
                            employeeName: employee.displayName ?? "-",
                            child: employee.avatarBytes != null
                                ? Image.memory(
                                    employee.avatarBytes!,
                                    height: 56,
                                    width: 56,
                                    fit: BoxFit.cover,
                                    errorBuilder: (context, error, stackTrace) {
                                      return Container(
                                        height: 56,
                                        width: 56,
                                        color: Colors.grey.shade300,
                                        alignment: Alignment.center,
                                        child: employee.name.isNotEmpty
                                            ? Text(
                                                employee.name[0].toUpperCase(),
                                                style: const TextStyle(
                                                  fontWeight: FontWeight.bold,
                                                  fontSize: 18,
                                                ),
                                              )
                                            : const Icon(
                                                Icons.person,
                                                size: 28,
                                                color: Colors.grey,
                                              ),
                                      );
                                    },
                                  )
                                : Container(
                                    height: 56,
                                    width: 56,
                                    color: Colors.grey.shade300,
                                    alignment: Alignment.center,
                                    child: employee.name.isNotEmpty
                                        ? Text(
                                            employee.name[0].toUpperCase(),
                                            style: const TextStyle(
                                              fontWeight: FontWeight.bold,
                                              fontSize: 18,
                                            ),
                                          )
                                        : const Icon(
                                            Icons.person,
                                            size: 28,
                                            color: Colors.grey,
                                          ),
                                  ),
                          );
                        },
                      ),
                    ),
            ),
          ],
        ),
      ),
    );
  }
}
