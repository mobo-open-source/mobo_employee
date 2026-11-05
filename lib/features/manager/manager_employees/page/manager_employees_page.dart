import 'package:flutter/material.dart';
import 'package:mobo_employees/features/manager/manager_employees/provider/manager_employees_provider.dart';
import 'package:mobo_employees/features/manager/manager_employees/widgets/employee_filter_sheet.dart';
import 'package:mobo_employees/features/manager/manager_employees/widgets/widget_employee_card.dart';
import 'package:mobo_employees/features/manager/manager_employees/widgets/widget_employee_card_shimmer.dart';
import 'package:mobo_employees/features/manager/manager_employees/model/model_fetch_manager_employee_details.dart'
    show ModelFetchManagerEmployeeDetails;
import 'package:mobo_employees/shared/widgets/connection_status_widget.dart';
import 'package:provider/provider.dart';
import '../../../../shared/widgets/cards/group_section_card.dart';
import '../../../../shared/widgets/no_results_empty_state.dart';
import '../../../../shared/widgets/filters/filter_status_row.dart';
import '../../../../shared/widgets/search/mobo_search_bar.dart';

/// The side inset of the toolbar (search bar and filter row).
const EdgeInsets _sideInset = EdgeInsets.symmetric(horizontal: 16);

/// The lists' own padding: the 16px side inset, a little room above the first
/// card and 16 under the last, so their shadows aren't clipped.
const EdgeInsets _listPadding = EdgeInsets.fromLTRB(16, 4, 16, 16);

/// Between two cards. As mobo CRM's customer list; Figma's is 11.
const double _cardGap = 12;

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
        // The side inset belongs to the toolbar and (as list padding) to the
        // lists, not to the whole body: a list clips what it paints to its own
        // bounds, so with the inset outside it the cards' soft shadows were cut
        // off flat at the 16px line.
        padding: const EdgeInsets.only(top: 16),
        child: Column(
          children: [
            Padding(
              padding: _sideInset,
              child: MoboSearchBar(
                controller: provider.searchEmployeeController,
                hintText: 'Search employees...',
                hasActiveFilter: provider.hasActiveFilter,
                onFilterTap: () => EmployeeFilterSheet.show(context),
                onChanged: (value) => provider.updateSearch(value),
              ),
            ),

            const SizedBox(height: 10),

            Padding(
              padding: _sideInset,
              child: FilterStatusRow(
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

                /// The count shows on a single page too; the arrows drop out
                /// on their own when there is nowhere to go.
                showPagination:
                    provider.totalRecords > 0 && !provider.isLoading,
              ),
            ),

            const SizedBox(height: 10),
            Expanded(
              child: provider.loadError != null
                  ? Padding(
                      padding: _sideInset,
                      child: ConnectionStatusWidget(
                        error: provider.loadError,
                        onRetry: provider.fetchEmployees,
                      ),
                    )
                  : provider.isLoading || provider.initialLoading == false
                  ? ListView.separated(
                      padding: _listPadding,
                      itemCount: 12,

                      /// shimmer count
                      separatorBuilder: (_, __) =>
                          const SizedBox(height: _cardGap),
                      itemBuilder: (_, __) => const WidgetEmployeeCardShimmer(),
                    )
                  : provider.employees.isEmpty
                  ? ListView(
                      physics: const AlwaysScrollableScrollPhysics(),
                      children: [
                        NoResultsEmptyState(
                          emptyTitle: 'No Employee Records Found',
                          showClearFilters: provider.narrowsResults,
                          onClearFilters:
                              provider.clearFiltersGroupingAndSearch,
                        ),
                      ],
                    )
                  : RefreshIndicator(
                      onRefresh: provider.refreshEmployees,
                      child: _EmployeeListBody(grouped: provider.grouped),
                    ),
            ),
          ],
        ),
      ),
    );
  }
}

class _EmployeeListBody extends StatefulWidget {
  final Map<String, List<ModelFetchManagerEmployeeDetails>> grouped;

  const _EmployeeListBody({required this.grouped});

  @override
  State<_EmployeeListBody> createState() => _EmployeeListBodyState();
}

class _EmployeeListBodyState extends State<_EmployeeListBody> {
  /// Groups the user closed. They start open: grouping happens on the page
  /// already loaded, so the employees are there to show.
  final Set<String> _collapsed = {};

  @override
  Widget build(BuildContext context) {
    final grouped = widget.grouped;
    final flat = grouped.length == 1 && grouped.containsKey('');

    if (flat) {
      final employees = grouped['']!;
      return ListView.separated(
        padding: _listPadding,
        itemCount: employees.length,
        separatorBuilder: (_, __) => const SizedBox(height: _cardGap),
        itemBuilder: (context, index) =>
            _EmployeeTile(employee: employees[index]),
      );
    }

    final groupKeys = grouped.keys.toList();
    return ListView.builder(
      padding: _listPadding,
      itemCount: groupKeys.length,
      itemBuilder: (context, groupIndex) {
        final key = groupKeys[groupIndex];
        final employees = grouped[key]!;
        final isExpanded = !_collapsed.contains(key);
        return GroupSectionCard(
          title: key,
          subtitle: employees.length == 1
              ? '1 employee'
              : '${employees.length} employees',
          isExpanded: isExpanded,
          onToggle: () => setState(() {
            isExpanded ? _collapsed.add(key) : _collapsed.remove(key);
          }),
          body: Column(
            children: [
              for (var i = 0; i < employees.length; i++)
                Padding(
                  padding: EdgeInsets.only(
                    bottom: i == employees.length - 1 ? 0 : 8,
                  ),
                  child: _EmployeeTile(employee: employees[i]),
                ),
            ],
          ),
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
              height: WidgetEmployeeCard.avatarSize,
              width: WidgetEmployeeCard.avatarSize,
              fit: BoxFit.cover,
              errorBuilder: (context, error, stackTrace) =>
                  _AvatarFallback(name: employee.name),
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
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Container(
      height: WidgetEmployeeCard.avatarSize,
      width: WidgetEmployeeCard.avatarSize,
      color: isDark ? Colors.grey.shade700 : Colors.grey.shade300,
      alignment: Alignment.center,
      child: name.isNotEmpty
          ? Text(
              name[0].toUpperCase(),
              style: TextStyle(
                fontWeight: FontWeight.bold,
                fontSize: 18,
                color: isDark ? Colors.white : Colors.black,
              ),
            )
          : const Icon(Icons.person, size: 28, color: Colors.grey),
    );
  }
}
