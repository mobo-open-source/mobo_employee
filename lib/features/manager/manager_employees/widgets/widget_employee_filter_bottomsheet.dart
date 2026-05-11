import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:mobo_employees/core/const/all_design.dart';
import 'package:mobo_employees/features/manager/manager_employees/provider/manager_employees_provider.dart';
import 'package:mobo_employees/features/manager/manager_employees/widgets/widget_filter_tile.dart';
import 'package:provider/provider.dart';

class WidgetEmployeesFilterBottomSheet extends StatelessWidget {
  const WidgetEmployeesFilterBottomSheet({super.key});

  @override
  Widget build(BuildContext context) {
    final isDarkTheme = Theme.of(context).brightness == Brightness.dark;

    return Consumer<ManagerEmployeesProvider>(
      builder: (context, provider, _) {
        return Container(
          height: MediaQuery.of(context).size.height * 0.55,
          padding: const EdgeInsets.symmetric(horizontal: 25, vertical: 30),
          decoration: BoxDecoration(
            color: isDarkTheme ? Colors.black : Colors.white,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              /// HEADER
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    "Filters",
                    style: GoogleFonts.manrope(
                      fontSize: 20,
                      fontWeight: FontWeight.w700,
                      color: isDarkTheme ? Colors.white : Colors.black,
                    ),
                  ),
                  IconButton(
                    icon: Icon(
                      Icons.close,
                      color: isDarkTheme ? Colors.white70 : Colors.black54,
                    ),
                    onPressed: () {
                      provider.prepareDraftFilters();
                      Navigator.pop(context);
                    },
                  ),
                ],
              ),

              const SizedBox(height: 20),

              /// ACTIVE FILTERS
              Text(
                "Active filters",
                style: GoogleFonts.manrope(
                  fontSize: 16,
                  fontWeight: FontWeight.w700,
                  color: AppColors.appColor,
                ),
              ),

              const SizedBox(height: 10),

              provider.draftFilters.isEmpty
                  ? Text(
                      "No active filters",
                      style: GoogleFonts.manrope(
                        color: isDarkTheme ? Colors.white70 : Colors.black54,
                      ),
                    )
                  : Wrap(
                      spacing: 10,
                      runSpacing: 10,
                      children: provider.draftFilters.map((filter) {
                        final label = _filterLabel(filter);
                        return InputChip(
                          label: Text(label),
                          onDeleted: () {
                            provider.toggleDraftFilter(filter);
                          },
                          deleteIconColor: AppColors.appColor,
                          backgroundColor: AppColors.appColor.withOpacity(.15),
                          labelStyle: const TextStyle(color: Colors.black),
                        );
                      }).toList(),
                    ),

              const SizedBox(height: 25),

              /// FILTER OPTIONS
              Text(
                "Filter by",
                style: GoogleFonts.manrope(
                  fontSize: 16,
                  fontWeight: FontWeight.w700,
                  color: AppColors.appColor,
                ),
              ),

              const SizedBox(height: 12),

              Expanded(
                child: SingleChildScrollView(
                  child: Wrap(
                    spacing: 10,
                    runSpacing: 5,
                    children: [
                      CommonFilterTile(
                        title: "At Work",
                        selected: provider.draftFilters.contains(
                          EmployeeFilter.atWork,
                        ),
                        onTap: () =>
                            provider.toggleDraftFilter(EmployeeFilter.atWork),
                      ),
                      CommonFilterTile(
                        title: "Absent",
                        selected: provider.draftFilters.contains(
                          EmployeeFilter.absent,
                        ),
                        onTap: () =>
                            provider.toggleDraftFilter(EmployeeFilter.absent),
                      ),
                      CommonFilterTile(
                        title: "My Team",
                        selected: provider.draftFilters.contains(
                          EmployeeFilter.myTeam,
                        ),
                        onTap: () =>
                            provider.toggleDraftFilter(EmployeeFilter.myTeam),
                      ),
                      CommonFilterTile(
                        title: "My Department",
                        selected: provider.draftFilters.contains(
                          EmployeeFilter.myDepartment,
                        ),
                        onTap: () => provider.toggleDraftFilter(
                          EmployeeFilter.myDepartment,
                        ),
                      ),
                    ],
                  ),
                ),
              ),

              const SizedBox(height: 20),

              /// FOOTER
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      style: OutlinedButton.styleFrom(
                        minimumSize: Size(120, 40),
                        side: BorderSide(color: AppColors.appColor, width: 1),
                        backgroundColor: Colors.white,
                        foregroundColor: Colors.black,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(8),
                        ),
                      ),
                      onPressed: () {
                        provider.clearAllFilters();
                        Navigator.pop(context);
                      },
                      child: Text(
                        "Clear All",
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
                        provider.applyDraftFilters();
                        Navigator.pop(context);
                      },
                      child: Text("Apply"),
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

  ///  Helper
  String _filterLabel(EmployeeFilter filter) {
    switch (filter) {
      case EmployeeFilter.atWork:
        return "At Work";
      case EmployeeFilter.absent:
        return "Absent";
      case EmployeeFilter.myTeam:
        return "My Team";
      case EmployeeFilter.myDepartment:
        return "My Department";
    }
  }
}
