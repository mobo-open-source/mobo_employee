import 'package:flutter/material.dart';
import 'package:flutter_staggered_grid_view/flutter_staggered_grid_view.dart';
import 'package:hugeicons/hugeicons.dart';
import 'package:mobo_employees/core/const/all_design.dart';
import 'package:mobo_employees/features/manager/manager_dashboard/provider/manager_dashboard_provider.dart';
import 'package:mobo_employees/widgets/managers/widget_manager_welcome_card.dart';
import 'package:mobo_employees/widgets/managers/widget_shimmer_manager_dashboard.dart';
import 'package:mobo_employees/widgets/widget_costoverviewcard.dart';
import 'package:mobo_employees/widgets/widget_recentActivity.dart';
import 'package:mobo_employees/features/profile/providers/profile_provider.dart';
import 'package:provider/provider.dart';

import '../../../review/services/review_service.dart';

class ManagerDashboardPage extends StatefulWidget {
  final bool isTest;
  const ManagerDashboardPage({super.key, this.isTest = false});

  @override
  State<ManagerDashboardPage> createState() => _ManagerDashboardPageState();
}

class _ManagerDashboardPageState extends State<ManagerDashboardPage> {
  Future<void> _onRefresh() async {
    await context.read<ManagerDashboardProvider>().refreshDashboard(
      isRefresh: true,
    );
  }

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      await context.read<ManagerDashboardProvider>().refreshDashboard();
    });
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      await ReviewService().checkAndShowRating(context);
    });
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

          if (provider.isInitialLoading ||
              provider.isManagerDashboardDataLoading == false) {
            return const WidgetShimmerManagerDashboard();
          }

          // Read live from ProfileProvider so avatar updates reflect immediately.
          final userAvatar = context.watch<ProfileProvider>().userAvatar;

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
                          "Good ${provider.dashboard.user.greetings} ${provider.dashboard.user.name}!",
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
                          ),
                        ),
                        StaggeredGridTile.fit(
                          crossAxisCellCount: 2,
                          child: WidgetRecentActivity(
                            isDarkTheme: isDarkTheme,
                            title: "Payslip",
                            subtitle: " payslip Generated",
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
                                "${provider.dashboard.todayReport.newLeaveRequestsForToday} new Leave requests",
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
