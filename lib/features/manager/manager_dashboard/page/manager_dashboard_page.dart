import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_staggered_grid_view/flutter_staggered_grid_view.dart';
import 'package:hugeicons/hugeicons.dart';
import 'package:intl/intl.dart';
import 'package:mobo_employees/core/const/all_design.dart';
import 'package:mobo_employees/features/manager/manager_approvals/providers/manager_approvals_provider.dart';
import 'package:mobo_employees/features/manager/manager_attendance/provider/manager_attendance_provider.dart';
import 'package:mobo_employees/features/manager/manager_dashboard/provider/manager_dashboard_provider.dart';
import 'package:mobo_employees/shared/widgets/connection_status_widget.dart';
import 'package:mobo_employees/widgets/managers/widget_manager_welcome_card.dart';
import 'package:mobo_employees/widgets/managers/widget_shimmer_manager_dashboard.dart';
import 'package:mobo_employees/widgets/widget_costoverviewcard.dart';
import 'package:mobo_employees/widgets/widget_recentActivity.dart';
import 'package:mobo_employees/features/profile/providers/profile_provider.dart';
import 'package:provider/provider.dart';

import '../../../review/services/review_service.dart';

class ManagerDashboardPage extends StatefulWidget {
  final bool isTest;

  /// Switches the bottom bar to another tab, for the cards that link to
  /// Attendance and Approvals. Without it the cards aren't tappable.
  final ValueChanged<int>? onOpenTab;

  const ManagerDashboardPage({super.key, this.isTest = false, this.onOpenTab});

  @override
  State<ManagerDashboardPage> createState() => _ManagerDashboardPageState();
}

class _ManagerDashboardPageState extends State<ManagerDashboardPage>
    with WidgetsBindingObserver {
  /// How often the day's figures (check-ins, late arrivals, leave requests)
  /// are re-read while the dashboard is on screen.
  static const Duration _autoRefreshEvery = Duration(minutes: 1);

  Timer? _autoRefreshTimer;

  Future<void> _onRefresh() async {
    await context.read<ManagerDashboardProvider>().refreshDashboard(
      isRefresh: true,
    );
  }

  /// Bottom bar tabs (see ManagerBottomNavbarPage) and the Approvals
  /// page's Time Off tab.
  static const int _attendanceTab = 1;
  static const int _approvalsTab = 3;
  static const int _timeOffApprovalsTab = 1;

  /// Today's attendances: what "Todays attendance" counts, and where the
  /// late check-ins can be seen.
  VoidCallback? get _openTodayAttendance {
    final openTab = widget.onOpenTab;
    if (openTab == null) return null;
    return () {
      context.read<ManagerAttendanceProvider>().showTodayOnNextLoad();
      openTab(_attendanceTab);
    };
  }

  /// The time off requests awaiting approval.
  VoidCallback? get _openPendingApprovals {
    final openTab = widget.onOpenTab;
    if (openTab == null) return null;
    return () {
      context.read<ManagerApprovalsProvider>().setTab(_timeOffApprovalsTab);
      openTab(_approvalsTab);
    };
  }

  /// Re-reads the day's figures without the loading shimmer.
  void _refreshTodayCounts() {
    if (!mounted) return;
    context.read<ManagerDashboardProvider>().refreshTodayCounts();
  }

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _autoRefreshTimer = Timer.periodic(
      _autoRefreshEvery,
      (_) => _refreshTodayCounts(),
    );
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      await context.read<ManagerDashboardProvider>().refreshDashboard();
    });
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      await ReviewService().checkAndShowRating(context);
    });
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) _refreshTodayCounts();
  }

  @override
  void dispose() {
    _autoRefreshTimer?.cancel();
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (widget.isTest) {
      return _buildDashboardContent(context);
    }
    return _buildDashboardContent(context);
  }

  Widget _buildDashboardContent(BuildContext context) {
    return Scaffold(
      body: Consumer<ManagerDashboardProvider>(
        builder: (context, provider, _) {
          final isDarkTheme = Theme.of(context).brightness == Brightness.dark;

          if (provider.loadError != null) {
            return ConnectionStatusWidget(
              error: provider.loadError,
              onRetry: _onRefresh,
            );
          }
          if (provider.isInitialLoading ||
              provider.isManagerDashboardDataLoading == false) {
            return const WidgetShimmerManagerDashboard();
          }

          // Read live from ProfileProvider so avatar updates reflect immediately.
          final userAvatar = context.watch<ProfileProvider>().userAvatar;
          final payslips = provider.dashboard.todayReport.payslipsGenerated;
          final newLeaveRequests =
              provider.dashboard.todayReport.newLeaveRequestsForToday;

          return RefreshIndicator(
            onRefresh: provider.isManagerDashboardLoading
                ? () async {}
                : _onRefresh,
            color: AppColors.appColor,
            child: SingleChildScrollView(
              physics: const AlwaysScrollableScrollPhysics(),
              padding: const EdgeInsets.all(15),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                    WidgetManagerWelcomeCard(
                      wishText:
                          "Good ${provider.dashboard.user.greetings}, ${provider.dashboard.user.name.split(' ').first}!",
                      subText:
                          "Manage your administrator operations efficiently",
                      wishTextFontSize: 16,
                      subTextFontSize: 14,
                      userAvatar: userAvatar,
                      userName: provider.dashboard.user.name,
                      isDarkTheme: isDarkTheme,
                    ),
                    const SizedBox(height: 18),
                    Text(
                      "Quick Overview",
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w700,
                        color: isDarkTheme ? Colors.white : AppColors.color101828,
                      ),
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 16),
                    GridView.count(
                      crossAxisCount: 2,
                      shrinkWrap: true,
                      physics: const NeverScrollableScrollPhysics(),
                      crossAxisSpacing: 12,
                      mainAxisSpacing: 12,
                      childAspectRatio: 1.2,
                      children: [
                        WidgetQuickOverview(
                          count: provider.dashboard.overview.totalEmployees
                              .toString(),
                          title: "Employees",
                          subtitle: "Total Employees",
                          color: AppColors.Color43B75D,
                          icon: HugeIcons.strokeRoundedUserMultiple,
                          isDarkTheme: isDarkTheme,
                        ),
                        WidgetQuickOverview(
                          count: provider.dashboard.overview.todayAttendance
                              .toString(),
                          title: "Todays attendance",
                          subtitle: "Daily attendance",
                          color: AppColors.color007AFF,
                          icon: HugeIcons.strokeRoundedUserCheck01,
                          isDarkTheme: isDarkTheme,
                          onTap: _openTodayAttendance,
                        ),
                        WidgetQuickOverview(
                          isDarkTheme: isDarkTheme,
                          count: provider.dashboard.overview.todayLeaves
                              .toString(),
                          title: "Leaves",
                          subtitle: "Leaves on today",
                          color: AppColors.colorF30B0B,
                          icon: HugeIcons.strokeRoundedUserRemove01,
                        ),
                        WidgetQuickOverview(
                          isDarkTheme: isDarkTheme,
                          count: provider.dashboard.overview.leaveRequests
                              .toString(),
                          title: "Approvals",
                          subtitle:
                              "${provider.dashboard.overview.leaveRequests} Leave requests",
                          color: AppColors.Color009688,
                          icon: HugeIcons.strokeRoundedDocumentValidation,
                          onTap: _openPendingApprovals,
                        ),
                      ],
                    ),
                    const SizedBox(height: 18),
                    Text(
                      "Today's Reports",
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w700,
                        color: isDarkTheme ? Colors.white : AppColors.color101828,
                      ),
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 16),
                    StaggeredGrid.count(
                      crossAxisCount: 2,
                      mainAxisSpacing: 10,
                      crossAxisSpacing: 10,
                      children: [
                        StaggeredGridTile.fit(
                          crossAxisCellCount: 2,
                          child: WidgetRecentActivity(
                            isDarkTheme: isDarkTheme,
                            title: "Late Check-ins",
                            subtitle:
                                "${provider.dashboard.todayReport.lateCheckIns} Late check-ins",
                            color: AppColors.colorFFCC00,
                            icon: HugeIcons.strokeRoundedAlert02,
                            onTap: _openTodayAttendance,
                          ),
                        ),
                        if (payslips != null)
                          StaggeredGridTile.fit(
                            crossAxisCellCount: 2,
                            child: WidgetRecentActivity(
                              isDarkTheme: isDarkTheme,
                              title: "Payslip",
                              subtitle:
                                  "$payslips ${payslips == 1 ? 'payslip' : 'payslips'} generated for ${DateFormat('MMMM').format(DateTime.now())}",
                              color: AppColors.color009688,
                              icon: HugeIcons.strokeRoundedInvoice01,
                            ),
                          ),
                        StaggeredGridTile.fit(
                          crossAxisCellCount: 2,
                          child: WidgetRecentActivity(
                            isDarkTheme: isDarkTheme,
                            title: "Leave request",
                            subtitle:
                                "$newLeaveRequests ${newLeaveRequests == 1 ? 'leave request' : 'leave requests'} submitted today",
                            color: AppColors.colorC03355,
                            icon: HugeIcons.strokeRoundedInvoice01,
                          ),
                        ),
                        const SizedBox(height: 10),
                      ],
                    ),
                  ],
                ),
              ),
            );
          },
        ),
      );
  }
}
