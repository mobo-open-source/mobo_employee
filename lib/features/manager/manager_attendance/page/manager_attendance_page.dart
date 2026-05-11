import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:hugeicons/hugeicons.dart';
import 'package:mobo_employees/core/const/all_design.dart';
import 'package:mobo_employees/features/manager/manager_attendance/provider/manager_attendance_provider.dart';
import 'package:mobo_employees/features/manager/manager_attendance/service/manager_attendance_data_service.dart';
import 'package:mobo_employees/widgets/widget_search_bar_page.dart';
import 'package:provider/provider.dart';
import '../model/model_manager_attendance_data.dart';
import '../widgets/widget_attendance_filter_bottomsheet.dart';
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
    if (!provider.initialLoadDone) {
      WidgetsBinding.instance.addPostFrameCallback((_) async {
        await provider.initialLoad();
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDarkTheme = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            ///  SEARCH BAR — NOT inside Consumer
            WidgetSearchBarPage(
              leftIcon: HugeIcons.strokeRoundedFilterHorizontal,
              onTap: () {
                final provider = context.read<ManagerAttendanceProvider>();
                provider.prepareDraftFilters();
                showModalBottomSheet(
                  context: context,
                  isScrollControlled: true,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.vertical(
                      top: Radius.circular(20),
                    ),
                  ),
                  builder: (_) {
                    return Consumer<ManagerAttendanceProvider>(
                      builder: (_, provider, __) {
                        return CommonFilterBottomSheet(
                          title: "Group By",
                          isDarkTheme:
                              Theme.of(context).brightness == Brightness.dark,
                          primaryColor: AppColors.colorE53E5A,
                          provider: provider,
                          selectedGroups: provider.draftGroupBy,
                          onToggle: (value) {
                            provider.toggleDraftGroupBy(
                              value == "Month"
                                  ? AttendanceGroupBy.month
                                  : AttendanceGroupBy.employee,
                            );
                          },
                          onClear: () async {
                            await provider.clearAllFilters();
                          },
                          onApply: provider.applyDraftFilters,
                          sections: [
                            CommonFilterSection(
                              title: "Group By",
                              items: ["Month", "Employee"],
                            ),
                          ],
                        );
                      },
                    );
                  },
                );
              },
              rightIcon: HugeIcons.strokeRoundedCancel01,
              clearfield: context.read<ManagerAttendanceProvider>().clearSearch,
              iconSize: 20,
              iconColor: AppColors.color666666,
              controller: context
                  .read<ManagerAttendanceProvider>()
                  .searchController,
              provider: context.read<ManagerAttendanceProvider>(),
              isDarkTheme: isDarkTheme,
              hintText: 'Search by name',
            ),

            const SizedBox(height: 15),

            ///  ONLY THIS PART REBUILDS
            Expanded(
              child: Consumer<ManagerAttendanceProvider>(
                builder: (context, provider, _) {
                  if (provider.isLoading &&
                      provider.groupBy.isEmpty &&
                      provider.modelManagerAttendanceData == null) {
                    return const WidgetShimmerAttendancePage();
                  }

                  if (provider.isGroupLoading && provider.groupBy.isNotEmpty) {
                    return const WidgetShimmerAttendancePage();
                  }

                  return Column(
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          _buildFilterLabel(provider, isDarkTheme),

                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,

                            children: [
                              Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 10,
                                  vertical: 6,
                                ),
                                decoration: BoxDecoration(
                                  color: isDarkTheme
                                      ? AppColors.whiteColor.withOpacity(.2)
                                      : AppColors.white,
                                  borderRadius: BorderRadius.circular(20),
                                  border: Border.all(
                                    color: AppColors.whiteColor.withOpacity(.3),
                                  ),
                                ),
                                child: Text(
                                  provider.pageCountLabel,
                                  style: TextStyle(
                                    fontSize: 12,
                                    color: isDarkTheme
                                        ? AppColors.whiteColor
                                        : AppColors.greyShade700Color,
                                    fontWeight: FontWeight.w400,
                                    letterSpacing: 0,
                                  ),
                                ),
                              ),
                              InkWell(
                                onTap: provider.canGoPrev
                                    ? provider.loadPrevPage
                                    : null,
                                child: Icon(
                                  Icons.chevron_left,
                                  size: 20,
                                  color: provider.canGoPrev
                                      ? AppColors.greyShade700Color
                                      : AppColors.greyShade400Color,
                                ),
                              ),

                              const SizedBox(width: 6),

                              InkWell(
                                onTap: provider.canGoNext
                                    ? provider.loadNextPage
                                    : null,
                                child: Icon(
                                  Icons.chevron_right,
                                  size: 20,
                                  color: provider.canGoNext
                                      ? AppColors.greyShade700Color
                                      : AppColors.greyShade400Color,
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                      const SizedBox(height: 10),
                      Expanded(
                        child: Card(
                          color: Colors.white,
                          elevation: 1,
                          child: Padding(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 12,
                              vertical: 8,
                            ),
                            child: RefreshIndicator(
                              onRefresh: provider.refreshPage,
                              child: ListView(
                                physics: const AlwaysScrollableScrollPhysics(),
                                children: [
                                  SingleChildScrollView(
                                    scrollDirection: Axis.horizontal,
                                    child: SizedBox(
                                      width: MediaQuery.of(context).size.width,
                                      child: Column(
                                        children: [
                                          const AttendanceTableHeader(),
                                          const SizedBox(height: 10),
                                          _buildAttendanceBody(provider),
                                        ],
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
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

Widget _buildAttendanceBody(ManagerAttendanceProvider provider) {
  /// No grouping → flat list
  if (provider.groupBy.isEmpty) {
    if (provider.modelManagerAttendanceData == null) {
      return const Center(child: Text('No attendance data'));
    }
    return _MonthAttendanceList(
      records: provider.modelManagerAttendanceData!.attendanceRecords,
      provider: provider,
    );
  }

  /// Multi-group recursive view
  return _RecursiveGroupView(
    provider: provider,
    groupOrder: provider.groupBy,
    level: 0,
    accumulatedDomain: const [
      ['employee_id.active', '=', true],
    ],
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

  @override
  Widget build(BuildContext context) {
    if (widget.level >= widget.groupOrder.length) {
      final data = widget.provider.getGroupAttendance(widget.accumulatedDomain);

      if (data == null ||
          widget.provider.isGroupAttendanceLoading(widget.accumulatedDomain)) {
        WidgetsBinding.instance.addPostFrameCallback((_) {
          widget.provider.fetchAttendanceForDomain(widget.accumulatedDomain);
        });
        return const Padding(
          padding: EdgeInsets.all(12),
          child: CircularProgressIndicator(strokeWidth: 2),
        );
      }

      return _MonthAttendanceList(
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

        return const Padding(
          padding: EdgeInsets.all(12),
          child: CircularProgressIndicator(strokeWidth: 2),
        );
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
        return const Padding(
          padding: EdgeInsets.all(12),
          child: CircularProgressIndicator(strokeWidth: 2),
        );
      }
      groups = data.groups;
    }

    if (groups.isEmpty) {
      return const Padding(
        padding: EdgeInsets.all(12),
        child: Text('No grouped data'),
      );
    }

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
            border: Border.all(color: AppColors.colorE5E7EB, width: 1),
            borderRadius: BorderRadius.circular(8),
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
                      : AppColors.color000000,
                ),
              ),

              onExpansionChanged: (expanded) {
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
                final nextDomain = [
                  ...widget.accumulatedDomain,
                  ...g.extraDomain,
                ];

                if (nextLevel == AttendanceGroupBy.month) {
                  widget.provider.fetchMonthGroupsForDomain(nextDomain);
                } else {
                  widget.provider.fetchEmployeeGroupsForDomain(nextDomain);
                }
              },

              children: [
                _RecursiveGroupView(
                  provider: widget.provider,
                  groupOrder: widget.groupOrder,
                  level: widget.level + 1,
                  accumulatedDomain: [
                    ...widget.accumulatedDomain,
                    ...g.extraDomain,
                  ],
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}

class AttendanceTableHeader extends StatelessWidget {
  const AttendanceTableHeader({super.key});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: AppColors.colorF9FAFB,
        borderRadius: BorderRadius.circular(4),
        border: Border.all(color: AppColors.colorE5E7EB, width: 1),
      ),
      child: Row(
        children: [
          Expanded(
            flex: 6,
            child: Text(
              'Employee',
              style: GoogleFonts.inter(
                fontSize: 14,
                fontWeight: FontWeight.w500,
                color: AppColors.color000000,
              ),
            ),
          ),
          Expanded(
            flex: 3,
            child: Text(
              'Check In',
              style: GoogleFonts.inter(
                fontSize: 14,
                fontWeight: FontWeight.w500,
                color: AppColors.color000000,
              ),
            ),
          ),
          Expanded(
            flex: 3,
            child: Text(
              'Check Out',
              style: GoogleFonts.inter(
                fontSize: 14,
                fontWeight: FontWeight.w500,
                color: AppColors.color000000,
              ),
            ),
          ),
          Expanded(
            flex: 3,
            child: Text(
              'Worked',
              textAlign: TextAlign.right,
              style: GoogleFonts.inter(
                fontSize: 14,
                fontWeight: FontWeight.w500,
                color: AppColors.color000000,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _MonthAttendanceList extends StatelessWidget {
  final List<AttendanceRecord> records;
  final ManagerAttendanceProvider provider;

  const _MonthAttendanceList({required this.records, required this.provider});

  @override
  Widget build(BuildContext context) {
    return ListView.separated(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      itemCount: records.length,
      separatorBuilder: (_, __) =>
          Divider(height: .1, color: Colors.transparent),
      itemBuilder: (context, index) {
        final r = records[index];
        final name = r.employee?.name ?? '-';
        final userId = r.employee?.id;
        final imageBytes = userId != null
            ? provider.getEmployeeImage(userId)
            : null;

        if (userId != null) {
          WidgetsBinding.instance.addPostFrameCallback((_) {
            provider.loadEmployeeImage(userId);
          });
        }

        return Padding(
          padding: const EdgeInsets.symmetric(vertical: 8),
          child: Container(
            padding: EdgeInsets.symmetric(vertical: 2, horizontal: 2),

            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                CircleAvatar(
                  radius: 16,
                  backgroundColor: AppColors.colorE53E5A,
                  child: ClipOval(
                    child: imageBytes != null && imageBytes.isNotEmpty
                        ? Image.memory(
                            imageBytes,
                            width: 32,
                            height: 32,
                            fit: BoxFit.cover,
                            errorBuilder: (context, error, stackTrace) {
                              return Center(
                                child: Text(
                                  name.isNotEmpty
                                      ? name.substring(0, 2).toUpperCase()
                                      : '--',
                                  style: TextStyle(
                                    color: AppColors.colorFFFFFF,
                                    fontSize: 11,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              );
                            },
                          )
                        : Center(
                            child: Text(
                              name.isNotEmpty
                                  ? name.substring(0, 2).toUpperCase()
                                  : '--',
                              style: TextStyle(
                                color: AppColors.colorFFFFFF,
                                fontSize: 11,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ),
                  ),
                ),

                const SizedBox(width: 10),

                Expanded(
                  flex: 5,
                  child: Text(
                    name,
                    style: GoogleFonts.manrope(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),

                Expanded(
                  flex: 3,
                  child: Text(
                    provider.formatTimeAMPM(r.checkIn),
                    style: GoogleFonts.manrope(fontSize: 11),
                  ),
                ),

                Expanded(
                  flex: 3,
                  child: Text(
                    provider.formatTimeAMPM(r.checkOut),
                    style: GoogleFonts.manrope(fontSize: 11),
                  ),
                ),

                Expanded(
                  flex: 3,
                  child: Text(
                    provider.formatWorkedHours(r.workedHours),
                    textAlign: TextAlign.right,
                    style: GoogleFonts.manrope(
                      fontSize: 11,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}

Widget _buildFilterLabel(ManagerAttendanceProvider provider, bool isDarkTheme) {
  final count = provider.activeFilterCount;

  if (count == 0) {
    return Text(
      'No filters applied',
      style: GoogleFonts.manrope(
        fontSize: 12,
        fontWeight: FontWeight.w500,
        color: AppColors.color4A5565,
      ),
    );
  }

  return Container(
    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
    decoration: BoxDecoration(
      color: Colors.black,
      borderRadius: BorderRadius.circular(12),
    ),
    child: Text(
      count == 1 ? '1 Active filter' : '$count Active filters',
      style: GoogleFonts.manrope(
        fontSize: 12,
        fontWeight: FontWeight.w600,
        color: Colors.white,
        letterSpacing: .3,
      ),
    ),
  );
}
