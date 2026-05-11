import 'package:flutter/material.dart';
import 'package:lottie/lottie.dart';
import 'package:mobo_employees/features/employee/leave/widget/my_calender_widget.dart';
import 'package:provider/provider.dart';

import '../../../../widgets/managers/index_click_common_widget/page_index_click.dart';
import '../provider/leave_page_provider.dart';
import '../widget/widget_my_time_off_page.dart';
import '../widget/widget_speed_dial.dart';

/// A page that allows employees to view their leave calendar and manage time-off requests.
///
/// It provides a tabbed interface to switch between [MyCalenderWidger] and a list
/// of the user's time-off applications.
class LeavePage extends StatefulWidget {
  const LeavePage({super.key});

  @override
  State<LeavePage> createState() => _LeavePageState();
}

/// The state for [LeavePage], handling data initialization and tab switching.
class _LeavePageState extends State<LeavePage> {
  /// The index of the currently selected tab (0 for Calendar, 1 for Time Off).
  int selectedIndex = 0;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      initialLoading();
    });
  }

  /// Fetches the initial data required for the leave page, including calendar
  /// events, unusual days, and time-off records.
  initialLoading() async {
    try {
      final leaveProvider = Provider.of<LeavePageProvider>(
        context,
        listen: false,
      );
      await leaveProvider.loadInitialOfMyCalender();
      await leaveProvider.fetchUserUnusualDays();
      await leaveProvider.fetchMyTimeOff();
    } catch (e) {}
  }

  @override
  Widget build(BuildContext context) {
    final isDarkTheme = Theme.of(context).brightness == Brightness.dark;
    final List<Widget> selectedWidgets = [
      const MyCalenderWidger(),
      buildAdministratorSelectedView(),
    ];
    return Scaffold(
      floatingActionButton: selectedIndex == 1
          ? WidgetSpeedDial()
          : SizedBox.shrink(),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 15),
            child: CommonActivityTabSelector(
              tabs: const ["My Calendar", "Time Off"],
              selectedIndex: selectedIndex,
              isDarkTheme: isDarkTheme,
              onChanged: (index) {
                setState(() {
                  selectedIndex = index;
                });
              },
            ),
          ),
          const SizedBox(height: 10),

          Expanded(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 15),
              child: selectedWidgets[selectedIndex],
            ),
          ),
        ],
      ),
    );
  }

  /// Builds the view for the "Time Off" tab.
  ///
  /// Displays a list of leave requests with their current status.
  /// If no records are found, an empty state animation is shown.
  Widget buildAdministratorSelectedView() {
    return Consumer<LeavePageProvider>(
      builder: (context, provider, _) {
        if (provider.isLoading) {
          return const Center(child: CircularProgressIndicator());
        }

        if (provider.timeOffList.isEmpty) {
          return Center(
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
                const Text("No leave records found"),
              ],
            ),
          );
        }

        return RefreshIndicator(
          onRefresh: provider.refreshMyTimeOff,
          child: ListView.separated(
            itemCount: provider.timeOffList.length,
            separatorBuilder: (_, __) => const SizedBox(height: 12),
            itemBuilder: (context, index) {
              final item = provider.timeOffList[index];

              return WidgetMyTimeOffPage(
                leaveName: item.leaveTypeName ?? "",
                status: item.state == 'cancel'
                    ? "Cancelled"
                    : item.state == 'confirm'
                    ? "To Approve"
                    : item.state == 'refuse'
                    ? "Rejected"
                    : item.state == "validate"
                    ? "Approved"
                    : item.state == "validate1"
                    ? "Second Approval"
                    : item.state,
                reason: item.description,
                appliedDate: item.create_date,
                leaveTypeandTime:
                    '${item.dateFromFormatted} - ${item.dateToFormatted} . ${item.durationDisplay} ',
              );
            },
          ),
        );
      },
    );
  }
}
