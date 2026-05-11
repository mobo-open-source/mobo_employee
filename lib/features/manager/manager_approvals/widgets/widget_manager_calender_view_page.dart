import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:hugeicons/hugeicons.dart';
import 'package:intl/intl.dart';
import 'package:mobo_employees/core/const/all_design.dart';
import 'package:mobo_employees/features/manager/manager_approvals/providers/manager_approvals_provider.dart';
import 'package:mobo_employees/features/manager/manager_approvals/widgets/app_shimmer.dart';
import 'package:mobo_employees/features/manager/manager_approvals/widgets/widget_card.dart';
import 'package:mobo_employees/features/manager/manager_approvals/widgets/widget_leave_calendar.dart';
import 'package:provider/provider.dart';

class WidgetManagerCalenderViewPage extends StatelessWidget {
  const WidgetManagerCalenderViewPage({super.key});

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<ManagerApprovalsProvider>();


    return RefreshIndicator(
      onRefresh: provider.refreshAll,
      child: SingleChildScrollView(
        padding: const EdgeInsets.only(top: 8),
        child: Column(
          children: [
            /// ───── Dashboard Cards (horizontal scroll allowed) ─────
            SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: provider.isLoading
                    ? List.generate(
                        3,
                        (_) => Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 4),
                          child: AppShimmer(
                            width: 160,
                            height: 90,
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                      )
                    : [
                        DashboardStatCard(
                          color: AppColors.colorC03355,
                          icon: HugeIcons.strokeRoundedUmbrella,
                          count: provider.remainingLeaves.toStringAsFixed(
                            0,
                          ), ///provider.maxLeaves.toStringAsFixed(0),
                          title: "Paid Time Off",
                          subtitle: "Until ${provider.paidOffValidUntil}",
                        ),
                        const SizedBox(width: 5),
                        DashboardStatCard(
                          color: AppColors.Color0095FF,
                          icon: HugeIcons.strokeRoundedDollarCircle,
                          count: provider.compensatoryLeaves.toStringAsFixed(
                            0,
                          ), /// provider.compensatoryMaxLeaves.toStringAsFixed(0),
                          title: "Compensatory Days",
                          subtitle: "Until ${provider.compensatoryValidUntil}",
                        ),
                        const SizedBox(width: 5),
                        DashboardStatCard(
                          color: AppColors.colorFFCC3D,
                          icon: HugeIcons.strokeRoundedTimeQuarter,
                          count: provider.allocationRequestCount
                              .toStringAsFixed(0),
                          title: "Pending",
                          subtitle: "Request pending",
                        ),
                      ],
              ),
            ),

            const SizedBox(height: 12),

            /// ───── Calendar (MUST have fixed width) ─────
             Consumer<ManagerApprovalsProvider>(
              builder: (context, provider, _) {
                if (provider.isCalendarLoading) {
                   return CalendarShimmer();
                }
                return const WidgetLeaveCalendar();
              },
            ),
            const SizedBox(height: 12),
            provider.isLoading
                ? Column(
                    children: List.generate(
                      3,
                      (_) => Padding(
                        padding: const EdgeInsets.symmetric(vertical: 6),
                        child: AppShimmer(
                          width: double.infinity,
                          height: 90,
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                    ),
                  )
                : provider.selectedDateEvents.isEmpty
                ? const SizedBox()
                : Padding(
                    padding: const EdgeInsets.symmetric(vertical: 6),
                    child: Container(
                      width: MediaQuery.of(context).size.width,
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(12),
                        color: AppColors.colorFFFFFF,
                      ),
                      child: Padding(
                        padding: const EdgeInsets.all(10),
                        child: Column(
                          children: List.generate(
                            provider.selectedDateEvents.length,
                            (index) {
                              final leave = provider.selectedDateEvents[index];
                              final from = leave.dateFrom ?? DateTime.now();
                              final to = leave.dateTo ?? DateTime.now();
                              bool showDate = true;
                              String formattedDate;
                              if (from.year == to.year &&
                                  from.month == to.month &&
                                  from.day == to.day) {
                                formattedDate = DateFormat(
                                  'MMM dd, yyyy',
                                ).format(from);
                              } else {
                                final formattedFrom = DateFormat(
                                  'MMM dd',
                                ).format(from);
                                final formattedTo = DateFormat(
                                  'MMM dd, yyyy',
                                ).format(to);
                                formattedDate = '$formattedFrom - $formattedTo';
                              }
                              if (index > 0) {
                                final prev =
                                    provider.selectedDateEvents[index - 1];
                                final prevFrom =
                                    prev.dateFrom ?? DateTime.now();
                                final prevTo = prev.dateTo ?? DateTime.now();

                                String prevFormatted;

                                if (prevFrom.year == prevTo.year &&
                                    prevFrom.month == prevTo.month &&
                                    prevFrom.day == prevTo.day) {
                                  prevFormatted = DateFormat(
                                    'MMM dd, yyyy',
                                  ).format(prevFrom);
                                } else {
                                  prevFormatted =
                                      '${DateFormat('MMM dd').format(prevFrom)} - ${DateFormat('MMM dd, yyyy').format(prevTo)}';
                                }

                                if (prevFormatted == formattedDate) {
                                  showDate = false;
                                }
                              }

                              String _calculateTotalDays(
                                DateTime? from,
                                DateTime? to,
                              ) {
                                if (from == null || to == null) return "1 Day";

                                final difference =
                                    to.difference(from).inDays + 1;

                                if (difference == 1) {
                                  return "1 Day";
                                } else {
                                  return "$difference Days";
                                }
                              }

                              return Padding(
                                padding: const EdgeInsets.symmetric(
                                  vertical: 6,
                                ),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    /// Date
                                    if (showDate)
                                      Text(
                                        formattedDate,
                                        style: GoogleFonts.manrope(
                                          color: AppColors.color000000,
                                          fontWeight: FontWeight.w600,
                                          fontSize: 14,
                                        ),
                                      ),
                                    if (showDate) SizedBox(height: 10),
                                    Row(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          "${leave.description} - ${_calculateTotalDays(leave.dateFrom, leave.dateTo)}",
                                          style: GoogleFonts.manrope(
                                            fontSize: 11,
                                            fontWeight: FontWeight.w400,
                                            color: AppColors.Color4E4E4E,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ],
                                ),
                              );
                            },
                          ).toList(),
                        ),
                      ),
                    ),
                  ),
          ],
        ),
      ),
    );

  }
}
