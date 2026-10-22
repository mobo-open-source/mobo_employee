import 'package:flutter/material.dart';
import 'package:flutter_staggered_grid_view/flutter_staggered_grid_view.dart';
import 'package:hugeicons/hugeicons.dart';
import 'package:intl/intl.dart';
import 'package:mobo_employees/core/const/all_design.dart';
import 'package:mobo_employees/shared/widgets/connection_status_widget.dart';
import 'package:mobo_employees/widgets/shimmer_widgets/shimmer_dashboard.dart';
import 'package:mobo_employees/widgets/widget_checkin_card.dart';
import 'package:mobo_employees/widgets/widget_costoverviewcard.dart';
import 'package:mobo_employees/widgets/widget_recentActivity.dart';
import 'package:mobo_employees/widgets/widget_welcomecard.dart';
import 'package:mobo_employees/features/profile/providers/profile_provider.dart';
import 'package:mobo_employees/shared/services/payslip_service.dart';
import 'package:provider/provider.dart';
import '../../../review/services/review_service.dart';
import '../provider/dashboard_provider.dart';

class DashboardPage extends StatefulWidget {
  final bool isTest;
  const DashboardPage({super.key, this.isTest = false});

  @override
  State<DashboardPage> createState() => _DashboardPageState();
}

class _DashboardPageState extends State<DashboardPage> {
  Future<void> _onRefresh() async {
    await context.read<DashboardProvider>().refreshDashboard(isRefresh: true);
  }

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      await context.read<DashboardProvider>().refreshDashboard();
    });
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      await ReviewService().checkAndShowRating(context);
    });
  }

  /// Net salary of [payslip] in its own currency.
  String _formatSalary(PayslipInfo payslip) {
    final amount = payslip.netWage ?? 0;
    final code = payslip.currencyCode;
    if (code == null) return NumberFormat.decimalPattern().format(amount);
    return NumberFormat.simpleCurrency(name: code).format(amount);
  }

  Color _payslipStateColor(String? state) {
    switch (state) {
      case 'paid':
        return Colors.green;
      case 'done':
      case 'validated':
        return Colors.blue;
      case 'verify':
        return Colors.orange;
      case 'cancel':
        return Colors.red;
      default:
        return Colors.grey;
    }
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
      body: Consumer<DashboardProvider>(
        builder: (context, provider, _) {
          final isDarkTheme = Theme.of(context).brightness == Brightness.dark;

          if (provider.loadError != null) {
            return ConnectionStatusWidget(
              error: provider.loadError,
              onRetry: _onRefresh,
            );
          }
          if (provider.isDashboardLoading ||
              provider.isDashboardNewDataLoading == false) {
            return DashboardShimmer(isDarkTheme: isDarkTheme);
          }
          final data = provider.dashboard;
          final payslips = provider.payslipSummary;
          final lastCredited = payslips?.lastCredited;
          final latestPayslip = payslips?.latest;

          final userAvatar = context.watch<ProfileProvider>().userAvatar;

          return RefreshIndicator(
            onRefresh: _onRefresh,
            color: AppColors.appColor,
            child: SingleChildScrollView(
              physics: const AlwaysScrollableScrollPhysics(),
              padding: const EdgeInsets.all(15),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                    WelcomeCard(
                      wishText: "Good ${data.greetings} ${data.userName}!",
                      subText:
                          "Manage your administrator operations efficiently",
                      wishTextFontSize: 16,
                      subTextFontSize: 14,
                      userAvatar: userAvatar,
                      userName: data.userName,
                      isDarkTheme: isDarkTheme,
                    ),
                    const SizedBox(height: 18),
                    WidgetCheckInCard(
                      isDarkTheme: isDarkTheme,
                      text: provider.isAttendanceCheckedIn
                          ? "Checked In"
                          : provider.isCheckedOutToday
                          ? "Checked Out"
                          : "Not Checked In",
                      subtext: provider.isAttendanceCheckedIn
                          ? (provider.checkInn ?? "")
                          : provider.isCheckedOutToday
                          ? (provider.checkOut ?? "")
                          : provider.currentTime,
                      color: AppColors.Color4E4E4E,
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
                          count:
                              "${data.yesterdayWorkingHours.toStringAsFixed(2)} hrs",
                          title: "Productive hrs",
                          subtitle: "Yesterdays",
                          color: AppColors.Color0095FF,
                          icon: HugeIcons.strokeRoundedClock01,
                          isDarkTheme: isDarkTheme,
                        ),
                        if (payslips != null)
                          WidgetQuickOverview(
                            count: lastCredited?.netWage != null
                                ? _formatSalary(lastCredited!)
                                : "—",
                            title: "Credited",
                            subtitle: lastCredited != null
                                ? "Salary for ${lastCredited.periodLabel}"
                                : "No salary credited yet",
                            color: AppColors.Color43B75D,
                            icon: HugeIcons.strokeRoundedDollar02,
                            isDarkTheme: isDarkTheme,
                          ),
                        WidgetQuickOverview(
                          isDarkTheme: isDarkTheme,
                          count:
                              "${data.leaveBalance.toStringAsFixed(0)} Days",
                          title: "Leave",
                          subtitle: "Leave Balance",
                          color: AppColors.Color9C27B0,
                          icon: HugeIcons.strokeRoundedCalendar04,
                        ),
                        WidgetQuickOverview(
                          isDarkTheme: isDarkTheme,
                          count: data.leaveRequestCount.toString(),
                          title: "Requests",
                          subtitle: "Leave Requests",
                          color: AppColors.ColorFF9800,
                          icon: HugeIcons.strokeRoundedAlertCircle,
                        ),
                        WidgetQuickOverview(
                          isDarkTheme: isDarkTheme,
                          count: data.nextLeaveDate ?? 'None',
                          title: "Holiday",
                          subtitle: data.nextLeaveDate == null
                              ? "No upcoming holiday"
                              : provider.nextHolidayName != null
                              ? "Next: ${provider.nextHolidayName}"
                              : "Next Holiday",
                          color: AppColors.colorC03355,
                          icon: HugeIcons.strokeRoundedProfile,
                        ),
                        if (payslips != null)
                          WidgetQuickOverview(
                            isDarkTheme: isDarkTheme,
                            count: "${payslips.confirmedCount}",
                            title: "Payslip",
                            subtitle: payslips.confirmedCount == 1
                                ? "Payslip issued"
                                : "Payslips issued",
                            color: AppColors.Color009688,
                            icon: HugeIcons.strokeRoundedInvoice01,
                          ),
                      ],
                    ),
                    const SizedBox(height: 18),
                    Text(
                      "Recent Activity",
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
                            title: data.recentLeave != null
                                ? data.recentLeave!.holidayStatusName
                                : "No Recent Leave",
                            subtitle: data.recentLeave != null
                                ? "Your Leave request ${provider.getLeaveStatusText(data.recentLeave!.state)}"
                                : "No recent leave activity",
                            color: data.recentLeave != null
                                ? AppColors.colorC03355
                                : Colors.grey,
                            icon: HugeIcons.strokeRoundedCalendar04,
                            statusText: data.recentLeave != null
                                ? provider.getLeaveStatusText(
                                    data.recentLeave!.state,
                                  )
                                : "",
                            statusColor: data.recentLeave != null
                                ? provider.getLeaveStatusColor(
                                    data.recentLeave!.state,
                                  )
                                : Colors.grey,
                          ),
                        ),
                        if (payslips != null)
                          StaggeredGridTile.fit(
                            crossAxisCellCount: 2,
                            child: WidgetRecentActivity(
                              isDarkTheme: isDarkTheme,
                              statusText: latestPayslip?.stateLabel ?? "",
                              statusColor: _payslipStateColor(
                                latestPayslip?.state,
                              ),
                              title: "Payslip",
                              subtitle: latestPayslip != null
                                  ? "Payslip for ${latestPayslip.periodLabel}"
                                  : "No payslips yet",
                              color: AppColors.Color009688,
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
