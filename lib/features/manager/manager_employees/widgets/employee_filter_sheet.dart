import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../provider/manager_employees_provider.dart';
import '../../../../shared/widgets/sheets/filter_bottom_sheet.dart';

/// Feature instantiation of the shared [FilterBottomSheet] for the manager
/// employees list — defines the Filter sections + Group By options and
/// wires them to [ManagerEmployeesProvider].
class EmployeeFilterSheet {
  EmployeeFilterSheet._();

  static const _sections = <FilterSection<EmployeeFilter>>[
    FilterSection(title: 'Status', [
      (EmployeeFilter.atWork, 'At Work'),
      (EmployeeFilter.absent, 'Absent'),
      (EmployeeFilter.myTeam, 'My Team'),
      (EmployeeFilter.myDepartment, 'My Department'),
    ]),
  ];

  static const _groupByOptions = <GroupByOption<EmployeeGroupBy>>[
    GroupByOption(EmployeeGroupBy.none, 'None', 'Display as a simple list'),
    GroupByOption(EmployeeGroupBy.department, 'Department',
        'Group employees by department'),
    GroupByOption(EmployeeGroupBy.jobPosition, 'Job Position',
        'Group employees by job title'),
    GroupByOption(EmployeeGroupBy.attendance, 'Attendance',
        'Group employees by attendance status'),
  ];

  static Future<void> show(BuildContext context) {
    final p = context.read<ManagerEmployeesProvider>();
    p.prepareDraftFilters();
    return showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => FilterBottomSheet<EmployeeFilter, EmployeeGroupBy>(
        filterSections: _sections,
        initialSelected: p.draftFilters,
        groupByOptions: _groupByOptions,
        initialGroupBy: {p.draftGroupBy},
        onApply: (selected, groupBy, _, __) =>
            p.applyFilterAndGroup(selected, groupBy.isEmpty ? EmployeeGroupBy.none : groupBy.first),
        onClearAll: () async => p.clearAllFilters(),
      ),
    );
  }
}
