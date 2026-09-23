import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../provider/manager_attendance_provider.dart';
import '../../../../shared/widgets/sheets/filter_bottom_sheet.dart';

/// Manager attendance instantiation of the shared [FilterBottomSheet].
/// Group By allows multi-select (Month + Employee can combine for drill-down).
class AttendanceFilterSheet {
  AttendanceFilterSheet._();

  static const _sections = <FilterSection<AttendanceFilter>>[
    FilterSection(title: 'Ownership', [
      (AttendanceFilter.myTeam, 'My Team'),
    ]),
    FilterSection(title: 'Schedule', [
      (AttendanceFilter.today, 'Today'),
      (AttendanceFilter.thisWeek, 'This Week'),
    ]),
    FilterSection(title: 'Status', [
      (AttendanceFilter.checkedIn, 'Checked In'),
      (AttendanceFilter.checkedOut, 'Checked Out'),
    ]),
  ];

  static const _groupByOptions = <GroupByOption<AttendanceGroupBy>>[
    GroupByOption(
        AttendanceGroupBy.month, 'Month', 'Group attendance by month'),
    GroupByOption(AttendanceGroupBy.employee, 'Employee',
        'Group attendance by employee'),
  ];

  static Future<void> show(BuildContext context) {
    final p = context.read<ManagerAttendanceProvider>();
    p.prepareDraftFilters();
    return showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => FilterBottomSheet<AttendanceFilter, AttendanceGroupBy>(
        filterSections: _sections,
        initialSelected: p.draftFilters,
        allowMultipleGroupBy: true,
        groupByOptions: _groupByOptions,
        initialGroupBy: {...p.draftGroupBy},
        dateRangeTitle: 'Attendance Date',
        initialStartDate: p.draftFilterStartDate,
        initialEndDate: p.draftFilterEndDate,
        onApply: (selected, groupBy, start, end) =>
            p.applyFilterAndGroupBy(selected, groupBy, start, end),
        onClearAll: () async {
          p.resetDraftFilters();
          await p.fetchAllAttendances();
        },
      ),
    );
  }
}
