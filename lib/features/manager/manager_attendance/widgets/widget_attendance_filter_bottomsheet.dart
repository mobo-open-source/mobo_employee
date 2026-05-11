import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:hugeicons/hugeicons.dart';
import 'package:mobo_employees/core/const/all_design.dart';
import 'package:mobo_employees/features/manager/manager_attendance/provider/manager_attendance_provider.dart';

import 'package:provider/provider.dart';



class WidgetAttendanceFilterBottomSheet extends StatelessWidget {
  const WidgetAttendanceFilterBottomSheet({super.key});

  @override
  Widget build(BuildContext context) {
    final isDarkTheme = Theme.of(context).brightness == Brightness.dark;

    return Consumer<ManagerAttendanceProvider>(
      builder: (context, provider, _) {
        return Container(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: isDarkTheme ? Colors.black : Colors.white,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              /// Header
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    'Group By',
                    style: GoogleFonts.manrope(
                      fontSize: 18,
                      fontWeight: FontWeight.w700,
                      color: isDarkTheme ? Colors.white : Colors.black,
                    ),
                  ),
                  IconButton(
                    icon: HugeIcon(
                      icon: HugeIcons.strokeRoundedCancel01,
                      color: AppColors.greyShade700Color,
                    ),
                    onPressed: () => Navigator.pop(context),
                  ),
                ],
              ),

              const SizedBox(height: 20),

              /// Month option
              _GroupByTile(
                title: 'Month',
                selected: provider.draftGroupBy.contains(
                  AttendanceGroupBy.month,
                ),
                onTap: () {
                  provider.toggleDraftGroupBy(AttendanceGroupBy.month);
                },
              ),

              const SizedBox(height: 10),

              /// Employee option
              _GroupByTile(
                title: 'Employee',
                selected: provider.draftGroupBy.contains(
                  AttendanceGroupBy.employee,
                ),
                onTap: () {
                  provider.toggleDraftGroupBy(AttendanceGroupBy.employee);
                },
              ),

              const SizedBox(height: 30),

              /// Footer buttons
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      onPressed: () {
                        provider.resetDraftFilters();
                        Navigator.pop(context);
                      },
                      style: OutlinedButton.styleFrom(
                        side: BorderSide(color: AppColors.colorE5E7EB),
                        padding: const EdgeInsets.symmetric(vertical: 12),
                      ),
                      child: const Text('Clear'),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: ElevatedButton(
                      onPressed: () {
                        provider.applyDraftFilters();
                        Navigator.pop(context);
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.colorE53E5A,
                        padding: const EdgeInsets.symmetric(vertical: 12),
                      ),
                      child: const Text('Apply'),
                    ),
                  ),
                ],
              ),
            ],
          ),
        );
      },
    );
  }
}

class _GroupByTile extends StatelessWidget {
  final String title;
  final bool selected;
  final VoidCallback onTap;

  const _GroupByTile({
    required this.title,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      borderRadius: BorderRadius.circular(12),
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: selected ? AppColors.appColor : AppColors.colorE5E7EB,
          ),
          color: selected
              ? AppColors.colorE53E5A.withOpacity(0.1)
              : Colors.transparent,
        ),
        child: Row(
          children: [
            Icon(
              selected ? Icons.check_circle : Icons.circle_outlined,
              color: selected ? AppColors.colorE53E5A : AppColors.appColor,
              size: 20,
            ),
            const SizedBox(width: 12),
            Text(
              title,
              style: GoogleFonts.manrope(
                fontSize: 14,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class CommonFilterSection {
  final String title;
  final List<String> items;

  CommonFilterSection({required this.title, required this.items});
}

class CommonFilterBottomSheet extends StatelessWidget {
  final String title;
  final bool isDarkTheme;
  final Color primaryColor;
  final List<AttendanceGroupBy> selectedGroups;
  final List<CommonFilterSection> sections;
  final ManagerAttendanceProvider provider;
  final void Function(String value) onToggle;
  final VoidCallback onClear;
  final VoidCallback onApply;

  const CommonFilterBottomSheet({
    super.key,
    required this.title,
    required this.isDarkTheme,
    required this.primaryColor,
    required this.selectedGroups,
    required this.sections,
    required this.onToggle,
    required this.onClear,
    required this.provider,
    required this.onApply,
  });

  @override
  Widget build(BuildContext context) {
    return ConstrainedBox(
      constraints: BoxConstraints(
        minHeight: MediaQuery.of(context).size.height * 0.4,
      ),
      child: IntrinsicHeight(
        child: Container(
          decoration: BoxDecoration(
            color: AppColors.whiteColor,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
          ),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 25, vertical: 30),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                /// HEADER
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      title,
                      style: TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.w700,
                        color: isDarkTheme ? Colors.white : Colors.black,
                      ),
                    ),
                    IconButton(
                      icon: const Icon(Icons.close),
                      onPressed: () {
                        onClear();
                        Navigator.pop(context);
                      },
                    ),
                  ],
                ),

                const SizedBox(height: 20),

                /// ACTIVE FILTERS
                Text(
                  "Active filters",
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w700,
                    color: AppColors.appColor,
                  ),
                ),

                const SizedBox(height: 10),

                selectedGroups.isEmpty
                    ? Text(
                        "No active filters",
                        style: TextStyle(color: Colors.black54),
                      )
                    : Wrap(
                        spacing: 10,
                        runSpacing: 10,
                        children: selectedGroups.map((group) {
                          final label = group == AttendanceGroupBy.month
                              ? "Month"
                              : "Employee";

                          return Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 12,
                              vertical: 8,
                            ),
                            decoration: BoxDecoration(
                              color: AppColors.appColor.withOpacity(0.1),
                              border: Border.all(
                                color: AppColors.appColor.withOpacity(0.1),
                              ),
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Text(
                                  label,
                                  style: TextStyle(
                                    fontSize: 14,
                                    fontWeight: FontWeight.w500,
                                    color: AppColors.blackColor,
                                    letterSpacing: 0,
                                  ),
                                ),
                                const SizedBox(width: 6),
                                GestureDetector(
                                  onTap: () {
                                    provider.toggleDraftGroupBy(group);
                                  },
                                  child: HugeIcon(
                                    icon: HugeIcons.strokeRoundedCancel01,
                                    size: 18,
                                    color: AppColors.blackColor,
                                  ),
                                ),

                                /// Delete button (replaces InputChip onDeleted)
                              ],
                            ),
                          );

                        }).toList(),
                      ),

                const SizedBox(height: 20),

                /// FILTER SECTIONS
                Expanded(
                  child: SingleChildScrollView(
                    child: Column(
                      children: sections.map((section) {
                        return Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              section.title,
                              style: TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.w700,
                                color: AppColors.appColor,
                              ),
                            ),
                            const SizedBox(height: 10),
                            SingleChildScrollView(
                              scrollDirection: Axis.horizontal,
                              child: Row(
                                children: section.items.map((item) {
                                  final group = provider.mapLabelToGroup(item);
                                  final selected = selectedGroups.contains(
                                    group,
                                  );
                                  return GestureDetector(
                                    onTap: () {
                                      onToggle(item);
                                    },
                                    child: Container(
                                      margin: const EdgeInsets.only(right: 10),
                                      padding: const EdgeInsets.symmetric(
                                        horizontal: 16,
                                        vertical: 10,
                                      ),
                                      decoration: BoxDecoration(
                                        color: selected
                                            ? AppColors.appColor
                                            : AppColors.appColor.withOpacity(
                                                .1,
                                              ),
                                        borderRadius: BorderRadius.circular(12),
                                      ),
                                      child: Row(
                                        children: [
                                          selected
                                              ? Row(
                                                  children: [
                                                    HugeIcon(
                                                      icon: HugeIcons
                                                          .strokeRoundedTick01,
                                                      size: 18,
                                                      color:
                                                          AppColors.whiteColor,
                                                    ),
                                                    const SizedBox(width: 5),
                                                  ],
                                                )
                                              : SizedBox.shrink(),
                                          Text(
                                            item,
                                            style: TextStyle(
                                              color: selected
                                                  ? AppColors.whiteColor
                                                  : AppColors.blackColor,
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                  );
                                }).toList(),
                              ),
                            ),
                            const SizedBox(height: 20),
                          ],
                        );
                      }).toList(),
                    ),
                  ),
                ),

                /// FOOTER
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton(
                        style: OutlinedButton.styleFrom(
                          minimumSize: Size(120, 40),
                          side: BorderSide(color: AppColors.appColor, width: 1),
                          backgroundColor: AppColors.whiteColor,
                          foregroundColor: Colors.black,

                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(8),
                          ),
                        ),

                        onPressed: () {
                          provider.resetDraftFilters();
                          Navigator.pop(context);
                          provider.fetchAllAttendances();
                        },
                        child: Text(
                          "Clear All",
                          maxLines: 1,
                          softWrap: false,
                          style: TextStyle(color: AppColors.appColor),
                        ),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: ElevatedButton(
                        style: ElevatedButton.styleFrom(
                          minimumSize: Size(120, 40),

                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(8),
                          ),
                        ),
                        onPressed: () {
                          onApply();
                          Navigator.pop(context);
                        },
                        child: const Text("Apply"),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
