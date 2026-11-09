import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import 'package:mobo_employees/core/const/all_design.dart';
import 'package:mobo_employees/features/employee/leave/provider/leave_page_provider.dart';
import 'package:mobo_employees/features/employee/leave/service/leave_service.dart';
import 'package:mobo_employees/features/employee/leave/widget/my_leave_calender.dart';
import 'package:mobo_employees/features/manager/manager_approvals/widgets/app_shimmer.dart';
import 'package:mobo_employees/features/employee/leave/widget/time_off_balance_cards.dart';
import 'package:mobo_employees/shared/widgets/connection_status_widget.dart';
import 'package:provider/provider.dart';

import '../../../../core/services/odoo_session_manager.dart';

class MyCalenderWidger extends StatelessWidget {
  const MyCalenderWidger({super.key});

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Consumer<LeavePageProvider>(
      builder: (context, provider, _) {
        if (provider.loadError != null) {
          return ConnectionStatusWidget(
            error: provider.loadError,
            onRetry: provider.refreshMyCalender,
          );
        }

        if (provider.isLoading || provider.isInitialLoadDone == false) {
          return SingleChildScrollView(
            physics: const AlwaysScrollableScrollPhysics(),
            child: Column(
              children: [
                SizedBox(height: 110, child: _buildShimmerLoading()),
                const SizedBox(height: 20),
                // The same inset as the calendar it stands in for.
                Padding(
                  padding: EdgeInsets.symmetric(horizontal: 5),
                  child: CalendarShimmer(),
                ),
              ],
            ),
          );
        }

        return RefreshIndicator(
          onRefresh: provider.refreshMyCalender,
          child: SingleChildScrollView(
            physics: const AlwaysScrollableScrollPhysics(),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                TimeOffBalanceCards(
                  balances: provider.timeOffBalances,
                  pendingCount: provider.pendingMyRequest,
                  pendingSubtitle: "Leave requests",
                ),

                const SizedBox(height: 20),

                const Padding(
                  padding: EdgeInsets.symmetric(horizontal: 5),
                  child: MyLeaveCalender(),
                ),

                const SizedBox(height: 12),

                if (provider.selectedDateEvents.isNotEmpty)
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 6),
                    child: Container(
                      width: MediaQuery.of(context).size.width,
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(12),
                        color: isDark
                            ? AppColors.greyShade800Color
                            : AppColors.colorFFFFFF,
                      ),
                      child: Padding(
                        padding: const EdgeInsets.all(10),
                        child: Column(
                          children: List.generate(
                            provider.selectedDateEvents.length,
                            (index) =>
                                _buildLeaveItem(provider, index, isDark),
                          ),
                        ),
                      ),
                    ),
                  ),
                const SizedBox(height: 12),
              ],
            ),
          ),
        );
      },
    );
  }

  /// Leave List Item
  Widget _buildLeaveItem(LeavePageProvider provider, int index, bool isDark) {
    final leave = provider.selectedDateEvents[index];

    final from = leave.dateFrom ?? DateTime.now();
    final to = leave.dateTo ?? DateTime.now();

    bool showDate = true;

    String formattedDate;

    if (from.year == to.year && from.month == to.month && from.day == to.day) {
      formattedDate = DateFormat('MMM dd, yyyy').format(from);
    } else {
      formattedDate =
          "${DateFormat('MMM dd').format(from)} - ${DateFormat('MMM dd, yyyy').format(to)}";
    }

    // Prevent duplicate date headers
    if (index > 0) {
      final prev = provider.selectedDateEvents[index - 1];
      final prevFrom = prev.dateFrom ?? DateTime.now();
      final prevTo = prev.dateTo ?? DateTime.now();

      String prevFormatted;

      if (prevFrom.year == prevTo.year &&
          prevFrom.month == prevTo.month &&
          prevFrom.day == prevTo.day) {
        prevFormatted = DateFormat('MMM dd, yyyy').format(prevFrom);
      } else {
        prevFormatted =
            "${DateFormat('MMM dd').format(prevFrom)} - ${DateFormat('MMM dd, yyyy').format(prevTo)}";
      }

      if (prevFormatted == formattedDate) {
        showDate = false;
      }
    }

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (showDate)
            Text(
              formattedDate,
              style: GoogleFonts.manrope(
                color: isDark ? Colors.white : AppColors.color000000,
                fontWeight: FontWeight.w600,
                fontSize: 14,
              ),
            ),

          if (showDate) const SizedBox(height: 10),

          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                "${leave.description}",
                style: GoogleFonts.manrope(
                  fontSize: 11,
                  fontWeight: FontWeight.w400,
                  color: isDark ? Colors.white70 : AppColors.Color4E4E4E,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  /// Shimmer loading cards
  Widget _buildShimmerLoading() {
    return ListView.separated(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      scrollDirection: Axis.horizontal,
      itemCount: 3,
      separatorBuilder: (_, __) => const SizedBox(width: 12),
      itemBuilder: (_, __) => AppShimmer(
        width: 160,
        height: 100,
        borderRadius: BorderRadius.circular(16),
      ),
    );
  }
}
