import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import 'package:mobo_employees/core/const/all_design.dart';
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
    Future.microtask(() async {
      final attendance = context.read<AttendanceProvider>();
      final dashboard = context.read<DashboardProvider>();
      final employeeId = dashboard.employeeId;

      if (employeeId == null) {
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
    });
  }

  @override
  Widget build(BuildContext context) {
    final isDarkTheme = Theme.of(context).brightness == Brightness.dark;
    return Scaffold(
      body: SafeArea(
        child: Consumer<AttendanceProvider>(
          builder: (context, provider, _) {
            if (!provider.isInitialLoaded) {
              return const AttendancePageShimmer();
            }
            return RefreshIndicator(
              onRefresh: () async {
                provider.loadedMonths.clear();
                provider.hasLoadedOnce = false;
                final attendance = context.read<AttendanceProvider>();
                final dashboard = context.read<DashboardProvider>();
                final employeeId = dashboard.employeeId;
                if (employeeId == null) return;
                attendance.hasLoadedOnce = false;
                await attendance.refreshAttendance(
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

Widget monthOverview({required String text, required String value}) {
  return Row(
    mainAxisAlignment: MainAxisAlignment.spaceBetween,
    children: [
      Text(
        text,
        style: TextStyle(
          fontSize: 12,
          fontWeight: FontWeight.w400,
          letterSpacing: 0,
          color: AppColors.color6A7282,
        ),
        overflow: TextOverflow.ellipsis,
      ),
      Text(
        value,
        style: TextStyle(
          fontSize: 14,
          fontWeight: FontWeight.w400,
          letterSpacing: 0,
          color: AppColors.color101828,
        ),
        overflow: TextOverflow.ellipsis,
      ),
    ],
  );
}

Widget _attendanceStatusCard() {
  return Consumer2<AttendanceProvider, DashboardProvider>(
    builder: (context, provider1, provider2, _) {
      if (!provider1.isInitialLoaded) {
        return _attendanceSkeleton();
      }
      final emp = provider1.attendanceEmployeeModel;
      if (emp == null) return const SizedBox.shrink();
      final shiftTime = provider1.getCompanyShiftTime();
      return Container(
        decoration: BoxDecoration(
          color: Colors.white,
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
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      shiftTime != null
                          ? 'Shift Time $shiftTime'
                          : 'Shift Time -',
                      style: GoogleFonts.manrope(
                        fontSize: 11,
                        color: AppColors.Color4E4E4E,
                      ),
                    ),
                  ],
                ),
              ),
              _attendanceChip(
                !provider1.isPresent(provider1.selectedDay!),
                provider1.isLeave(provider1.selectedDay!),
              ),
            ],
          ),
        ),
      );
    },
  );
}

Widget _attendanceSkeleton() {
  return Card(
    elevation: 1,
    child: Padding(
      padding: const EdgeInsets.all(12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(height: 16, width: 120, color: Colors.grey.shade300),
          const SizedBox(height: 8),
          Container(height: 12, width: 180, color: Colors.grey.shade300),
        ],
      ),
    ),
  );
}

Widget _monthlyOverviewCard() {
  return Consumer<AttendanceProvider>(
    builder: (context, provider, _) {
      if (!provider.isInitialLoaded) {
        return _monthlySkeleton();
      }
      final emp = provider.attendanceEmployeeModel;

      if (emp == null)
        return Container(
          decoration: BoxDecoration(
            color: Colors.white,
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
                monthOverview(text: "Days Present", value: "0"),
                monthOverview(text: "Leave Days", value: "0"),
                monthOverview(text: "Total Hours", value: "0 h"),
                monthOverview(text: "Attendance", value: "0%"),
              ],
            ),
          ),
        );
      //final hours = provider.hoursToHHMM(emp.hoursLastMonth);
      return Container(
        decoration: BoxDecoration(
          color: Colors.white,
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
              ),
              monthOverview(
                text: "Leave Days",
                value: provider.monthlyLeaveCount.toString(),
              ),
              monthOverview(
                text: "Total Hours",
                value: "${emp.hoursLastMonth.toStringAsFixed(2)} h",
              ),
              monthOverview(
                text: "Attendance",
                value: "${provider.attendancePercentage.toStringAsFixed(1)}%",
              ),
            ],
          ),
        ),
      );
    },
  );
}

Widget _attendanceChip(bool isPrecent, bool isleave) {
  return Container(
    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
    decoration: BoxDecoration(
      color: isPrecent
          ? isleave
                ? Colors.red.shade100
                : Colors.orange.withOpacity(0.1)
          : AppColors.Color43B75D.withOpacity(0.1),
      borderRadius: BorderRadius.circular(20),
    ),
    child: Text(
      isPrecent == false
          ? 'Present'
          : isleave
          ? "Leave"
          : ' Absent',
      style: TextStyle(
        fontSize: 10,
        fontWeight: FontWeight.w700,
        color: isPrecent
            ? isleave
                  ? Colors.red
                  : Colors.orange
            : AppColors.Color43B75D,
      ),
    ),
  );
}

Widget _monthlySkeleton() {
  return Card(
    elevation: 1,
    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
    child: Padding(
      padding: const EdgeInsets.symmetric(horizontal: 21, vertical: 12),
      child: Column(
        children: [
          _skeletonRow(),
          const SizedBox(height: 8),
          _skeletonRow(),
          const SizedBox(height: 8),
          _skeletonRow(),
          const SizedBox(height: 8),
          _skeletonRow(),
        ],
      ),
    ),
  );
}

Widget _skeletonRow() {
  return Row(
    mainAxisAlignment: MainAxisAlignment.spaceBetween,
    children: [
      Container(
        height: 12,
        width: 100,
        decoration: BoxDecoration(
          color: Colors.grey.shade300,
          borderRadius: BorderRadius.circular(4),
        ),
      ),
      Container(
        height: 14,
        width: 50,
        decoration: BoxDecoration(
          color: Colors.grey.shade300,
          borderRadius: BorderRadius.circular(4),
        ),
      ),
    ],
  );
}
