  import 'package:flutter/material.dart';
import 'package:mobo_employees/core/const/all_design.dart';
import 'package:mobo_employees/features/manager/manager_attendance/provider/manager_attendance_provider.dart';
import 'package:mobo_employees/features/manager/manager_attendance/service/manager_attendance_data_service.dart';
import 'package:mobo_employees/core/theme/app_theme.dart';
import 'package:mobo_employees/shared/widgets/connection_status_widget.dart';
import 'package:provider/provider.dart';
import '../../../../shared/widgets/cards/group_tile_card.dart';
import '../../../../shared/widgets/no_results_empty_state.dart';
import '../../../../shared/widgets/filters/filter_status_row.dart';
import '../../../../shared/widgets/search/mobo_search_bar.dart';
import '../model/model_manager_attendance_data.dart';
import '../../../../widgets/snackbar_widgets.dart';
import '../widgets/attendance_card.dart';
import '../widgets/attendance_create_sheet.dart';
import '../widgets/attendance_filter_sheet.dart';
import '../widgets/attendance_table.dart';
import '../widgets/widget_shimmer_attendance_page.dart';

class ManagerAttendancePage extends StatefulWidget {
  const ManagerAttendancePage({super.key});

  @override
  State<ManagerAttendancePage> createState() => _ManagerAttendancePageState();
}

class _ManagerAttendancePageState extends State<ManagerAttendancePage> {
  @override
  void initState() {
    super.initState();
    final provider = context.read<ManagerAttendanceProvider>();
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      if (!provider.initialLoadDone) {
        await provider.initialLoad();
      } else {
        // Returning to the tab: re-read so attendances created or edited
        // in the Odoo backend meanwhile are shown.
        await provider.refreshPage();
      }
    });
  }

  Future<void> _createAttendance(ManagerAttendanceProvider provider) async {
    final created = await AttendanceCreateSheet.show(
      context,
      employeeDomain: provider.attendanceCreateDomain ?? const [],
    );
    if (!created || !mounted) return;
    CustomSnackbar.showSuccess(context, "Attendance created");
    await provider.refreshPage();
  }

  @override
  Widget build(BuildContext context) {
    final isDarkTheme = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      floatingActionButton: Consumer<ManagerAttendanceProvider>(
        builder: (context, provider, _) {
          if (!provider.canCreateAttendance) return const SizedBox.shrink();
          return FloatingActionButton(
            tooltip: "New Attendance",
            backgroundColor: AppColors.appColor,
            foregroundColor: Colors.white,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(15),
            ),
            onPressed: () => _createAttendance(provider),
            child: const Icon(Icons.add),
          );
        },
      ),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            Consumer<ManagerAttendanceProvider>(
              builder: (context, provider, __) {
                return MoboSearchBar(
                  controller: provider.searchController,
                  hintText: 'Search by name',
                  hasActiveFilter: provider.activeFilterCount > 0,
                  onFilterTap: () => AttendanceFilterSheet.show(context),
                  onChanged: (value) => provider.updateSearch(value),
                );
              },
            ),

            const SizedBox(height: 15),

            Expanded(
              child: Consumer<ManagerAttendanceProvider>(
                builder: (context, provider, _) {
                  if (provider.loadError != null) {
                    return ConnectionStatusWidget(
                      error: provider.loadError,
                      onRetry: provider.refreshPage,
                    );
                  }
                  if (provider.isFirstLoad) {
                    return const WidgetShimmerAttendancePage();
                  }

                  if (provider.isLoading &&
                      provider.groupBy.isEmpty &&
                      provider.modelManagerAttendanceData == null) {
                    return const WidgetShimmerAttendancePage();
                  }

                  if (provider.isGroupLoading && provider.groupBy.isNotEmpty) {
                    return const WidgetShimmerAttendancePage();
                  }

                  final grouped = provider.groupBy.isNotEmpty;
                  final groupLabel = grouped
                      ? provider.groupBy.map((g) => g.label).join(', ')
                      : null;

                  // Room under the last row so it can scroll clear of the
                  // New Attendance button.
                  final bottomPadding = provider.canCreateAttendance
                      ? AppSpacing.fabClearance
                      : 0.0;

                  return Column(
                    children: [
                      FilterStatusRow(
                        filterCount:
                            provider.activeFilters.length +
                            ((provider.filterStartDate != null ||
                                    provider.filterEndDate != null)
                                ? 1
                                : 0),
                        groupByLabel: groupLabel,
                        isDark: isDarkTheme,

                        // A grouped list counts its groups and has no pages
                        // to move through.
                        paginationText: grouped
                            ? provider.groupCountLabel
                            : provider.pageCountLabel,
                        canPrev: !grouped && provider.canGoPrev,
                        canNext: !grouped && provider.canGoNext,
                        onPrev: provider.loadPrevPage,
                        onNext: provider.loadNextPage,
                        showPagination: grouped
                            ? (provider.rootGroupCount ?? 0) > 0
                            : provider.totalAttendanceCount > 0 &&
                                  !provider.isLoading,
                      ),
                      const SizedBox(height: 10),
                      Expanded(
                        child: grouped
                            ? RefreshIndicator(
                                onRefresh: provider.refreshPage,
                                child: ListView(
                                  physics:
                                      const AlwaysScrollableScrollPhysics(),
                                  padding: EdgeInsets.only(
                                    top: 4,
                                    bottom: bottomPadding,
                                  ),
                                  children: [
                                    _RecursiveGroupView(
                                      provider: provider,
                                      groupOrder: provider.groupBy,
                                      level: 0,
                                      accumulatedDomain: provider.baseDomain,
                                    ),
                                  ],
                                ),
                              )
                            : _buildAttendanceTable(
                                context,
                                provider,
                                isDarkTheme,
                                bottomPadding,
                              ),
                      ),
                    ],
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// The ungrouped list: one card — a heading band over the rows (see
/// [AttendanceTable]).
Widget _buildAttendanceTable(
  BuildContext context,
  ManagerAttendanceProvider provider,
  bool isDark,
  double bottomPadding,
) {
  final records = provider.modelManagerAttendanceData?.attendanceRecords;
  if (records == null || records.isEmpty) {
    return RefreshIndicator(
      onRefresh: provider.refreshPage,
      child: ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        children: [_buildEmptyList(provider)],
      ),
    );
  }

  return RefreshIndicator(
    onRefresh: provider.refreshPage,
    child: ListView(
      physics: const AlwaysScrollableScrollPhysics(),
      // Room under the card for the shadow, and for the New Attendance button.
      padding: EdgeInsets.only(top: 4, bottom: bottomPadding + 12),
      children: [AttendanceTable(entries: _tableEntries(provider, records))],
    ),
  );
}

/// Whether [r] was checked out on a later day than it was checked in (an
/// overnight shift), so the check-out needs its own date.
bool _endsOnLaterDay(AttendanceRecord r) {
  final checkIn = r.checkIn;
  final checkOut = r.checkOut;
  if (checkIn == null || checkOut == null) return false;
  return DateUtils.dateOnly(checkOut).isAfter(DateUtils.dateOnly(checkIn));
}

/// [records] as the table shows them, and a nudge for the photo of each
/// employee not loaded yet (it arrives later and the table redraws).
List<AttendanceTableEntry> _tableEntries(
  ManagerAttendanceProvider provider,
  List<AttendanceRecord> records,
) {
  return [
    for (final r in records)
      () {
        final employeeId = r.employee?.id;
        final avatar = employeeId == null
            ? null
            : provider.getEmployeeImage(employeeId);
        if (employeeId != null && avatar == null) {
          WidgetsBinding.instance.addPostFrameCallback((_) {
            provider.loadEmployeeImage(employeeId);
          });
        }
        return AttendanceTableEntry(
          name: r.employee?.name ?? '-',
          avatar: avatar,
          date: provider.formatDate(r.checkIn, pattern: 'MMM dd'),
          checkIn: provider.formatTimeAMPM(r.checkIn),
          checkOut: provider.formatTimeAMPM(r.checkOut),
          checkOutDate: _endsOnLaterDay(r)
              ? provider.formatDate(r.checkOut, pattern: 'MMM dd')
              : null,
          worked: provider.formatWorkedHours(r.workedHours),
        );
      }(),
  ];
}

/// What an empty list shows: with a filter, the date range or a search
/// narrowing it, the way back out; otherwise just that there is nothing.
Widget _buildEmptyList(ManagerAttendanceProvider provider) {
  return NoResultsEmptyState(
    emptyTitle: 'No attendance data',
    showClearFilters: provider.narrowsResults,
    onClearFilters: provider.clearFiltersGroupingAndSearch,
  );
}

class _RecursiveGroupView extends StatefulWidget {
  final ManagerAttendanceProvider provider;
  final List<AttendanceGroupBy> groupOrder;
  final int level;
  final List<dynamic> accumulatedDomain;

  const _RecursiveGroupView({
    required this.provider,
    required this.groupOrder,
    required this.level,
    required this.accumulatedDomain,
  });

  @override
  State<_RecursiveGroupView> createState() => _RecursiveGroupViewState();
}

class _RecursiveGroupViewState extends State<_RecursiveGroupView> {
  final Set<int> expandedIndexes = {};

  static const Widget _spinner = Center(
    child: Padding(
      padding: EdgeInsets.all(12),
      child: SizedBox(
        width: 24,
        height: 24,
        child: CircularProgressIndicator(strokeWidth: 2),
      ),
    ),
  );

  /// Opens or closes group [index], fetching the level below it on open.
  void _setExpanded(int index, AttendanceGroupNode g, bool expanded) {
    setState(() {
      if (expanded) {
        expandedIndexes.add(index);
      } else {
        expandedIndexes.remove(index);
      }
    });

    if (!expanded) return;
    if (widget.level + 1 >= widget.groupOrder.length) return;

    final nextLevel = widget.groupOrder[widget.level + 1];
    final nextDomain = [...widget.accumulatedDomain, ...g.extraDomain];

    if (nextLevel == AttendanceGroupBy.month) {
      widget.provider.fetchMonthGroupsForDomain(nextDomain);
    } else {
      widget.provider.fetchEmployeeGroupsForDomain(nextDomain);
    }
  }

  Widget _levelBelow(AttendanceGroupNode g) {
    return _RecursiveGroupView(
      provider: widget.provider,
      groupOrder: widget.groupOrder,
      level: widget.level + 1,
      accumulatedDomain: [...widget.accumulatedDomain, ...g.extraDomain],
    );
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    if (widget.level >= widget.groupOrder.length) {
      final data = widget.provider.getGroupAttendance(widget.accumulatedDomain);

      if (data == null ||
          widget.provider.isGroupAttendanceLoading(widget.accumulatedDomain)) {
        WidgetsBinding.instance.addPostFrameCallback((_) {
          widget.provider.fetchAttendanceForDomain(widget.accumulatedDomain);
        });
        return _spinner;
      }

      return _AttendanceCardList(
        provider: widget.provider,
        records: data.attendanceRecords,
      );
    }

    final current = widget.groupOrder[widget.level];

    List<AttendanceGroupNode> groups;

    if (current == AttendanceGroupBy.month) {
      final data = widget.provider.getMonthGroups(widget.accumulatedDomain);
      if (data == null) {
        WidgetsBinding.instance.addPostFrameCallback((_) {
          widget.provider.fetchMonthGroupsForDomain(widget.accumulatedDomain);
        });
        return _spinner;
      }
      groups = data.groups;
    } else {
      final data = widget.provider.getEmployeeGroups(widget.accumulatedDomain);
      if (data == null) {
        WidgetsBinding.instance.addPostFrameCallback((_) {
          widget.provider.fetchEmployeeGroupsForDomain(
            widget.accumulatedDomain,
          );
        });
        return _spinner;
      }
      groups = data.groups;
    }

    if (groups.isEmpty) {
      if (widget.level == 0) return _buildEmptyList(widget.provider);
      return const Padding(
        padding: EdgeInsets.all(12),
        child: Text('No grouped data'),
      );
    }

    // Top level: one group tile each, as mobo Sales' grouped lists — the
    // records beneath an open group are cards, so there are no column
    // headings.
    if (widget.level == 0) {
      return Column(
        children: [
          for (var index = 0; index < groups.length; index++)
            GroupTileCard(
              title: groups[index].label,
              subtitle: groups[index].count == 1
                  ? '1 record'
                  : '${groups[index].count} records',
              isExpanded: expandedIndexes.contains(index),
              onToggle: () => _setExpanded(
                index,
                groups[index],
                !expandedIndexes.contains(index),
              ),
              body: _levelBelow(groups[index]),
            ),
        ],
      );
    }

    // Deeper levels sit inside a group card, so they get a compact
    // hairline header rather than another shadowed card.
    return ListView.separated(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      itemCount: groups.length,
      separatorBuilder: (_, __) =>
          Divider(height: 0.6, color: Colors.transparent),
      itemBuilder: (context, index) {
        final g = groups[index];
        return Container(
          margin: const EdgeInsets.symmetric(vertical: 4),
          decoration: BoxDecoration(
            border: Border.all(
              color: isDark ? Colors.white12 : AppColors.colorE5E7EB,
              width: 1,
            ),
            borderRadius: BorderRadius.circular(AppRadius.control),
          ),
          child: Theme(
            data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
            child: ExpansionTile(
              tilePadding: EdgeInsets.symmetric(horizontal: 8),
              childrenPadding: EdgeInsets.symmetric(horizontal: 8),

              title: Text(
                '${g.label} (${g.count})',
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.bold,
                  color: expandedIndexes.contains(index)
                      ? AppColors.appColor
                      : (isDark ? Colors.white : AppColors.color000000),
                ),
              ),

              onExpansionChanged: (expanded) =>
                  _setExpanded(index, g, expanded),

              children: [_levelBelow(g)],
            ),
          ),
        );
      },
    );
  }
}

/// The records of one group, as cards (see [AttendanceCard]). The ungrouped
/// list is the table of [AttendanceTable].
class _AttendanceCardList extends StatelessWidget {
  final List<AttendanceRecord> records;
  final ManagerAttendanceProvider provider;

  const _AttendanceCardList({required this.records, required this.provider});

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        for (final r in records)
          AttendanceCard(
            employee: r.employee?.name ?? '-',
            date: provider.formatDate(r.checkIn),
            checkIn: provider.formatTimeAMPM(r.checkIn),
            checkOut: provider.formatTimeAMPM(r.checkOut),
            checkOutDate: _endsOnLaterDay(r)
                ? provider.formatDate(r.checkOut, pattern: 'MMM dd')
                : null,
            worked: provider.formatWorkedHours(r.workedHours),
            isCheckedIn: r.checkOut == null,
          ),
      ],
    );
  }
}
