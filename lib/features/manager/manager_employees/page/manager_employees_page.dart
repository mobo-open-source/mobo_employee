import 'package:flutter/material.dart';
import 'package:lottie/lottie.dart';
import 'package:mobo_employees/core/const/all_design.dart';
import 'package:mobo_employees/features/manager/manager_employees/provider/manager_employees_provider.dart';
import 'package:mobo_employees/features/manager/manager_employees/widgets/employee_filter_sheet.dart';
import 'package:mobo_employees/features/manager/manager_employees/widgets/widget_employee_card.dart';
import 'package:mobo_employees/features/manager/manager_employees/widgets/widget_employee_card_shimmer.dart';
import 'package:mobo_employees/features/manager/manager_employees/model/model_fetch_manager_employee_details.dart'
    show ModelFetchManagerEmployeeDetails;
import 'package:provider/provider.dart';
import '../../../../shared/widgets/filters/filter_status_row.dart';
import '../../../../shared/widgets/search/mobo_search_bar.dart';

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
            MoboSearchBar(
              controller: provider.searchEmployeeController,
              hintText: 'Search employees...',
              hasActiveFilter: provider.hasActiveFilter,
              onFilterTap: () => EmployeeFilterSheet.show(context),
              onChanged: (value) => provider.updateSearch(value),
            ),

            const SizedBox(height: 10),

            FilterStatusRow(
              filterCount: provider.activeFilters.length,
              groupByLabel: provider.groupBy == EmployeeGroupBy.none
                  ? null
                  : provider.groupBy.label,
              isDark: isDarkTheme,
              paginationText: provider.paginationText,
              canPrev: provider.canGoPrevious,
              canNext: provider.canGoNext,
              onPrev: provider.previousPage,
              onNext: provider.nextPage,
              showPagination: provider.totalPages > 1,
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
                      child: _EmployeeListBody(
                        grouped: provider.grouped,
                        isDark: isDarkTheme,
                      ),
                    ),
            ),
          ],
        ),
      ),
    );
  }
}

class _EmployeeListBody extends StatelessWidget {
  final Map<String, List<ModelFetchManagerEmployeeDetails>> grouped;
  final bool isDark;

  const _EmployeeListBody({required this.grouped, required this.isDark});

  @override
  Widget build(BuildContext context) {
    final flat = grouped.length == 1 && grouped.containsKey('');

    if (flat) {
      final employees = grouped['']!;
      return ListView.separated(
        itemCount: employees.length,
        separatorBuilder: (_, __) => const SizedBox(height: 8),
        itemBuilder: (context, index) => _EmployeeTile(employee: employees[index]),
      );
    }

    final groupKeys = grouped.keys.toList();
    return ListView.builder(
      itemCount: groupKeys.length,
      itemBuilder: (context, groupIndex) {
        final key = groupKeys[groupIndex];
        final employees = grouped[key]!;
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: EdgeInsets.only(top: groupIndex == 0 ? 0 : 16, bottom: 8),
              child: Row(
                children: [
                  Text(
                    key,
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w700,
                      color: isDark ? Colors.white : AppColors.color101828,
                    ),
                  ),
                  const SizedBox(width: 8),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                    decoration: BoxDecoration(
                      color: AppColors.appColor.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Text(
                      '${employees.length}',
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                        color: AppColors.appColor,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            ...employees.map(
              (e) => Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: _EmployeeTile(employee: e),
              ),
            ),
          ],
        );
      },
    );
  }
}

class _EmployeeTile extends StatelessWidget {
  final ModelFetchManagerEmployeeDetails employee;

  const _EmployeeTile({required this.employee});

  @override
  Widget build(BuildContext context) {
    return WidgetEmployeeCard(
      employeeEmail: employee.workEmail ?? "-",
      employeePhone: employee.workPhone ?? "-",
      employeeJob: employee.jobTitle ?? "-",
      employeeName: employee.displayName ?? "-",
      child: employee.avatarBytes != null
          ? Image.memory(
              employee.avatarBytes!,
              height: 56,
              width: 56,
              fit: BoxFit.cover,
              errorBuilder: (context, error, stackTrace) => _AvatarFallback(name: employee.name),
            )
          : _AvatarFallback(name: employee.name),
    );
  }
}

class _AvatarFallback extends StatelessWidget {
  final String name;

  const _AvatarFallback({required this.name});

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 56,
      width: 56,
      color: Colors.grey.shade300,
      alignment: Alignment.center,
      child: name.isNotEmpty
          ? Text(
              name[0].toUpperCase(),
              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 18),
            )
          : const Icon(Icons.person, size: 28, color: Colors.grey),
    );
  }
}
