import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import 'package:mobo_employees/core/const/all_design.dart';
import 'package:mobo_employees/core/theme/app_theme.dart';
import 'package:mobo_employees/shared/widgets/connection_status_widget.dart';
import 'package:mobo_employees/widgets/snackbar_widgets.dart';
import 'package:mobo_employees/features/employee/attendance/provider/attendance_provider.dart';
import 'package:mobo_employees/features/employee/attendance/service/administrator_attendance_service.dart';
import 'package:mobo_employees/features/employee/dashboard/provider/dashboard_provider.dart';
import 'package:mobo_employees/widgets/shimmer_widgets/shimmer_attendance.dart';
import 'package:mobo_employees/widgets/widget_attendance_calender.dart';
import 'package:mobo_employees/widgets/widget_attendance_checkout_card.dart';
import 'package:mobo_employees/widgets/widget_checkin_card.dart';
import 'package:mobo_employees/widgets/widget_clock_timeline_card.dart';
import 'package:provider/provider.dart';

class AttendancePage extends StatefulWidget {
  const AttendancePage({super.key});

  @override
  State<AttendancePage> createState() => _AttendancePageState();
}

class _AttendancePageState extends State<AttendancePage> {
  @override
  void initState() {
    super.initState();
    Future.microtask(_loadAttendance);
  }

  Future<void> _loadAttendance() async {
    final attendance = context.read<AttendanceProvider>();
    final dashboard = context.read<DashboardProvider>();

    // The employee id comes from the dashboard's load; if that failed
    // (e.g. server unreachable), retry it before giving up.
    if (dashboard.employeeId == null && dashboard.loadError != null) {
      await dashboard.refreshDashboard(isRefresh: true);
      if (!mounted) return;
    }

    final employeeId = dashboard.employeeId;
    if (employeeId == null) {
      final dashboardError = dashboard.loadError;
      if (dashboardError != null) {
        attendance.setLoadError(dashboardError);
        return;
      }
      attendance.changeInitialLoading();
      CustomSnackbar.showError(
        context,
        "We couldn’t find this employee in the current company. Please verify the details.",
      );
      return;
    }
    await attendance.refreshAttendance(
      employeeId: employeeId,
      month: DateTime.now(),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isDarkTheme = Theme.of(context).brightness == Brightness.dark;
    return Scaffold(
      body: SafeArea(
        child: Consumer<AttendanceProvider>(
          builder: (context, provider, _) {
            if (provider.loadError != null) {
              return ConnectionStatusWidget(
                error: provider.loadError,
                onRetry: _loadAttendance,
              );
            }
            if (!provider.isInitialLoaded) {
              return AttendancePageShimmer(isDarkTheme: isDarkTheme);
            }
            return RefreshIndicator(
              onRefresh: () async {
                final employeeId = context.read<DashboardProvider>().employeeId;
                if (employeeId == null) return;
                await provider.refreshAttendance(
                  employeeId: employeeId,
                  month: DateTime.now(),
                );
              },
              child: CustomScrollView(
                physics: const AlwaysScrollableScrollPhysics(),
                slivers: [
                  SliverPadding(
                    padding: const EdgeInsets.all(16),
                    sliver: SliverList(
                      delegate: SliverChildListDelegate([
                        const WidgetAttendanceCheckoutCard(),

                        const SizedBox(height: 10),

                        WidgetAttendanceCalender(),

                        const SizedBox(height: 10),

                        _attendanceStatusCard(),

                        const SizedBox(height: 10),

                        Consumer<DashboardProvider>(
                          builder: (context, dashboard, _) {
                            return WidgetClockTimelineCard(
                              clockInTime: provider.checkInn ?? "--:--",
                              clockOutTime: provider.checkOut ?? "--:--",
                            );
                          },
                        ),

                        const SizedBox(height: 10),

                        const Text(
                          "This Month Overview",
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        const SizedBox(height: 10),
                        _monthlyOverviewCard(),
                      ]),
                    ),
                  ),
                ],
              ),
            );
          },
        ),
      ),
    );
  }
}

Widget monthOverview({
  required String text,
  required String value,
  required bool isDark,
}) {
  return Row(
    mainAxisAlignment: MainAxisAlignment.spaceBetween,
    children: [
      Text(
        text,
        style: TextStyle(
          fontSize: 12,
          fontWeight: FontWeight.w400,
          letterSpacing: 0,
          color: isDark ? Colors.white70 : AppColors.color6A7282,
        ),
        overflow: TextOverflow.ellipsis,
      ),
      Text(
        value,
        style: TextStyle(
          fontSize: 14,
          fontWeight: FontWeight.w400,
          letterSpacing: 0,
          color: isDark ? Colors.white : AppColors.color101828,
        ),
        overflow: TextOverflow.ellipsis,
      ),
    ],
  );
}

Widget _attendanceStatusCard() {
  return Consumer2<AttendanceProvider, DashboardProvider>(
    builder: (context, provider1, provider2, _) {
      final isDark = Theme.of(context).brightness == Brightness.dark;
      if (!provider1.isInitialLoaded) {
        return _attendanceSkeleton(isDark);
      }
      final emp = provider1.attendanceEmployeeModel;
      if (emp == null) return const SizedBox.shrink();
      final shiftTime = provider1.getCompanyShiftTime();
      return Container(
        decoration: BoxDecoration(
          color: isDark ? AppColors.greyShade800Color : Colors.white,
          borderRadius: BorderRadius.circular(12),
          boxShadow: [
            BoxShadow(
              color: AppColors.color000000.withOpacity(.04),
              offset: const Offset(3, 11),
              blurRadius: 8.5,
              spreadRadius: -3,
            ),
          ],
        ),
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      DateFormat('MMM dd, yyyy').format(provider1.selectedDay!),

                      style: GoogleFonts.manrope(
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                        color: isDark ? Colors.white : AppColors.color101828,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      shiftTime != null
                          ? 'Shift Time $shiftTime'
                          : 'Shift Time -',
                      style: GoogleFonts.manrope(
                        fontSize: 11,
                        color: isDark ? Colors.white70 : AppColors.Color4E4E4E,
                      ),
                    ),
                  ],
                ),
              ),
              _attendanceChip(
                !provider1.isPresent(provider1.selectedDay!),
                provider1.isLeave(provider1.selectedDay!),
                isDark,
              ),
            ],
          ),
        ),
      );
    },
  );
}

Widget _attendanceSkeleton(bool isDark) {
  return Card(
    color: isDark ? AppColors.greyShade800Color : Colors.white,
    elevation: 1,
    child: Padding(
      padding: const EdgeInsets.all(12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            height: 16,
            width: 120,
            color: isDark ? Colors.grey[700]! : Colors.grey.shade300,
          ),
          const SizedBox(height: 8),
          Container(
            height: 12,
            width: 180,
            color: isDark ? Colors.grey[700]! : Colors.grey.shade300,
          ),
        ],
      ),
    ),
  );
}

Widget _monthlyOverviewCard() {
  return Consumer<AttendanceProvider>(
    builder: (context, provider, _) {
      final isDark = Theme.of(context).brightness == Brightness.dark;
      if (!provider.isInitialLoaded) {
        return _monthlySkeleton(isDark);
      }
      final emp = provider.attendanceEmployeeModel;

      if (emp == null)
        return Container(
          decoration: BoxDecoration(
            color: isDark ? AppColors.greyShade800Color : Colors.white,
            borderRadius: BorderRadius.circular(12),
            boxShadow: [
              BoxShadow(
                color: AppColors.color000000.withOpacity(.04),
                offset: const Offset(3, 11),
                blurRadius: 8.5,
                spreadRadius: -3,
              ),
            ],
          ),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 21, vertical: 12),
            child: Column(
              children: [
                monthOverview(text: "Days Present", value: "0", isDark: isDark),
                monthOverview(text: "Leave Days", value: "0", isDark: isDark),
                monthOverview(
                  text: "Total Hours",
                  value: "0 h",
                  isDark: isDark,
                ),
                monthOverview(text: "Attendance", value: "0%", isDark: isDark),
              ],
            ),
          ),
        );
      return Container(
        decoration: BoxDecoration(
          color: isDark ? AppColors.greyShade800Color : Colors.white,
          borderRadius: BorderRadius.circular(12),
          boxShadow: [
            BoxShadow(
              color: AppColors.color000000.withOpacity(.04),
              offset: const Offset(3, 11),
              blurRadius: 8.5,
              spreadRadius: -3,
            ),
          ],
        ),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 21, vertical: 12),
          child: Column(
            children: [
              monthOverview(
                text: "Days Present",
                value: provider.monthlyAttendanceCount.toString(),
                isDark: isDark,
              ),
              monthOverview(
                text: "Leave Days",
                value: provider.monthlyLeaveCount.toString(),
                isDark: isDark,
              ),
              monthOverview(
                text: "Total Hours",
                value: "${emp.hoursLastMonth.toStringAsFixed(2)} h",
                isDark: isDark,
              ),
              monthOverview(
                text: "Attendance",
                value: "${provider.attendancePercentage.toStringAsFixed(1)}%",
                isDark: isDark,
              ),
            ],
          ),
        ),
      );
    },
  );
}

/// The selected day's status as the canonical badge: Present, Leave or
/// Absent.
Widget _attendanceChip(bool isAbsent, bool isLeave, bool isDark) {
  if (!isAbsent) {
    return StatusColors.buildStatusBadge(
      'Present',
      color: StatusColors.green,
      isDark: isDark,
    );
  }
  return StatusColors.buildStatusBadge(
    isLeave ? 'Leave' : 'Absent',
    color: isLeave ? StatusColors.red : StatusColors.orange,
    isDark: isDark,
  );
}

Widget _monthlySkeleton(bool isDark) {
  return Card(
    color: isDark ? AppColors.greyShade800Color : Colors.white,
    elevation: 1,
    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
    child: Padding(
      padding: const EdgeInsets.symmetric(horizontal: 21, vertical: 12),
      child: Column(
        children: [
          _skeletonRow(isDark),
          const SizedBox(height: 8),
          _skeletonRow(isDark),
          const SizedBox(height: 8),
          _skeletonRow(isDark),
          const SizedBox(height: 8),
          _skeletonRow(isDark),
        ],
      ),
    ),
  );
}

Widget _skeletonRow(bool isDark) {
  return Row(
    mainAxisAlignment: MainAxisAlignment.spaceBetween,
    children: [
      Container(
        height: 12,
        width: 100,
        decoration: BoxDecoration(
          color: isDark ? Colors.grey[700]! : Colors.grey.shade300,
          borderRadius: BorderRadius.circular(4),
        ),
      ),
      Container(
        height: 14,
        width: 50,
        decoration: BoxDecoration(
          color: isDark ? Colors.grey[700]! : Colors.grey.shade300,
          borderRadius: BorderRadius.circular(4),
        ),
      ),
    ],
  );
}
