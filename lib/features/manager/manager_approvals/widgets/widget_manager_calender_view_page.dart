import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import 'package:mobo_employees/core/const/all_design.dart';
import 'package:mobo_employees/features/manager/manager_approvals/models/model_leave_calendar_event.dart';
import 'package:mobo_employees/features/manager/manager_approvals/providers/manager_approvals_provider.dart';
import 'package:mobo_employees/features/manager/manager_approvals/widgets/app_shimmer.dart';
import 'package:mobo_employees/features/employee/leave/widget/time_off_balance_cards.dart';
import 'package:mobo_employees/features/manager/manager_approvals/widgets/widget_leave_calendar.dart';
import 'package:mobo_employees/shared/widgets/connection_status_widget.dart';
import 'package:provider/provider.dart';

class WidgetManagerCalenderViewPage extends StatefulWidget {
  const WidgetManagerCalenderViewPage({super.key});

  @override
  State<WidgetManagerCalenderViewPage> createState() =>
      _WidgetManagerCalenderViewPageState();
}

class _WidgetManagerCalenderViewPageState
    extends State<WidgetManagerCalenderViewPage> {
  final _dayDetailsKey = GlobalKey();

  /// The day whose details were last brought into view.
  DateTime? _revealedDate;

  /// The day's details sit under the calendar, so after tapping a day they can
  /// be off the bottom of the screen: scroll down to them — by only as much as
  /// it takes to bring them into view (nothing at all when they already are),
  /// so the calendar stays on screen as long as the details allow. A list too
  /// long for the screen is aligned to its top instead, so the date heading
  /// isn't the part that gets cut off.
  void _revealDayDetails(DateTime? selectedDate) {
    if (selectedDate == _revealedDate) return;
    _revealedDate = selectedDate;
    if (selectedDate == null) return;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final detailsContext = _dayDetailsKey.currentContext;
      if (detailsContext == null || !detailsContext.mounted) return;
      final size = (detailsContext.findRenderObject() as RenderBox?)?.size;
      final viewport = Scrollable.maybeOf(
        detailsContext,
      )?.position.viewportDimension;
      final tallerThanScreen =
          size != null && viewport != null && size.height > viewport;
      Scrollable.ensureVisible(
        detailsContext,
        duration: const Duration(milliseconds: 250),
        curve: Curves.easeOut,
        alignmentPolicy: tallerThanScreen
            ? ScrollPositionAlignmentPolicy.keepVisibleAtStart
            : ScrollPositionAlignmentPolicy.keepVisibleAtEnd,
      );
    });
  }

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<ManagerApprovalsProvider>();

    if (provider.loadError != null) {
      return ConnectionStatusWidget(
        error: provider.loadError,
        onRetry: provider.loadInitialData,
      );
    }

    final selectedDate = provider.selectedDate;
    _revealDayDetails(selectedDate);

    return RefreshIndicator(
      onRefresh: provider.refreshAll,
      child: SingleChildScrollView(
        padding: const EdgeInsets.only(top: 8, bottom: 12),
        child: Column(
          children: [
            /// ───── Dashboard Cards: one per time off type, as in Odoo ─────
            provider.isLoading
                ? SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    child: Row(
                      children: List.generate(
                        3,
                        (_) => Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 4),
                          child: AppShimmer(
                            width: 160,
                            height: 90,
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                      ),
                    ),
                  )
                : provider.timeOffDataFailed && provider.timeOffBalances.isEmpty
                /// Nothing to show and nothing loaded: say so and offer a
                /// retry, instead of leaving the area looking empty.
                ? _BalancesUnavailable(onRetry: provider.retryTimeOffData)
                : TimeOffBalanceCards(
                    balances: provider.timeOffBalances,
                    pendingCount: provider.pendingAllocationCount,
                    pendingSubtitle: "Allocation requests",
                  ),

            const SizedBox(height: 12),

            /// ───── Calendar (MUST have fixed width) ─────
            Consumer<ManagerApprovalsProvider>(
              builder: (context, provider, _) {
                if (provider.isCalendarLoading) {
                  return const CalendarShimmer();
                }
                return const WidgetLeaveCalendar();
              },
            ),

            /// ───── Selected day: under the calendar, the day's requests ─────
            if (selectedDate != null && !provider.isCalendarLoading) ...[
              const SizedBox(height: 12),
              _SelectedDayLeaves(
                key: _dayDetailsKey,
                date: selectedDate,
                leaves: provider.selectedDateEvents,
                onClose: provider.clearSelectedDate,
              ),
            ],
          ],
        ),
      ),
    );
  }
}

/// Shown where the balance cards go when they couldn't be loaded.
class _BalancesUnavailable extends StatelessWidget {
  final VoidCallback onRetry;

  const _BalancesUnavailable({required this.onRetry});

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(14, 10, 8, 10),
      decoration: BoxDecoration(
        color: isDark ? AppColors.greyShade800Color : AppColors.whiteColor,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: isDark ? Colors.white12 : AppColors.colorEDEDEB,
        ),
      ),
      child: Row(
        children: [
          Icon(
            Icons.info_outline_rounded,
            size: 18,
            color: isDark ? Colors.white70 : AppColors.color6A7282,
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              "Couldn't load your time off balances",
              style: GoogleFonts.manrope(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: isDark ? Colors.white70 : AppColors.color616161,
              ),
            ),
          ),
          TextButton(
            onPressed: onRetry,
            child: Text(
              'Retry',
              style: GoogleFonts.manrope(
                fontSize: 12,
                fontWeight: FontWeight.w700,
                color: AppColors.appColor,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// The time off of the day tapped in the calendar, each with its status in
/// the legend's colors.
class _SelectedDayLeaves extends StatelessWidget {
  final DateTime date;
  final List<LeaveCalendarEvent> leaves;
  final VoidCallback onClose;

  const _SelectedDayLeaves({
    super.key,
    required this.date,
    required this.leaves,
    required this.onClose,
  });

  static String _rangeLabel(LeaveCalendarEvent leave) {
    final from = leave.dateFrom;
    final to = leave.dateTo;
    if (from == null || to == null) return '';
    if (DateUtils.isSameDay(from, to)) {
      return DateFormat('MMM dd, yyyy').format(from);
    }
    return '${DateFormat('MMM dd').format(from)} - '
        '${DateFormat('MMM dd, yyyy').format(to)}';
  }

  static String _daysLabel(LeaveCalendarEvent leave) {
    final from = leave.dateFrom;
    final to = leave.dateTo;
    if (from == null || to == null) return '1 Day';
    final days =
        DateUtils.dateOnly(to).difference(DateUtils.dateOnly(from)).inDays + 1;
    return days == 1 ? '1 Day' : '$days Days';
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final titleColor = isDark ? Colors.white : AppColors.color000000;
    final detailColor = isDark ? Colors.white70 : AppColors.color6A7282;
    final dividerColor = isDark ? Colors.white12 : AppColors.colorEDEDEB;
    final headerLineColor = isDark ? Colors.white38 : AppColors.colorBDBDBD;
    final countLabel = leaves.length == 1
        ? '1 request'
        : '${leaves.length} requests';

    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        color: isDark ? AppColors.greyShade800Color : AppColors.colorFFFFFF,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: isDark ? Colors.white12 : AppColors.colorEDEDEB,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          /// ───── Header: the day, how many are off, close ─────
          Padding(
            padding: const EdgeInsets.fromLTRB(14, 8, 6, 0),
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    DateFormat('EEE, MMM dd, yyyy').format(date),
                    style: GoogleFonts.manrope(
                      fontSize: 14,
                      fontWeight: FontWeight.w700,
                      color: titleColor,
                    ),
                  ),
                ),
                if (leaves.isNotEmpty)
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 2,
                    ),
                    decoration: BoxDecoration(
                      color: AppColors.appColor.withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Text(
                      countLabel,
                      style: GoogleFonts.manrope(
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                        color: AppColors.appColor,
                      ),
                    ),
                  ),
                IconButton(
                  tooltip: 'Close',
                  visualDensity: VisualDensity.compact,
                  onPressed: onClose,
                  icon: Icon(Icons.close_rounded, size: 18, color: detailColor),
                ),
              ],
            ),
          ),

          /// Grey line separating the heading from the requests below. It sits
          /// outside the card padding so it runs the full width of the card.
          Divider(height: 12, thickness: 1, color: headerLineColor),

          Padding(
            padding: const EdgeInsets.fromLTRB(14, 0, 6, 12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (leaves.isEmpty)
                  // A lone line of text would sit hard against the heading's
                  // line and the card's bottom edge: give it room — about 18
                  // under the line (the divider's own 6, and 12 more) and 18
                  // above the edge (the body's 12, and 6 more).
                  Padding(
                    padding: const EdgeInsets.only(top: 12, bottom: 6),
                    child: Text(
                      'No time off on this day',
                      style: GoogleFonts.manrope(
                        fontSize: 12,
                        color: detailColor,
                      ),
                    ),
                  ),

                /// ───── One row per time off ─────
                for (var i = 0; i < leaves.length; i++) ...[
                  if (i > 0) Divider(height: 16, color: dividerColor),
                  Padding(
                    padding: const EdgeInsets.only(right: 8),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // The status is the dot's colour, as in the calendar's legend —
                        // not spelled out again on the right of each request.
                        Padding(
                          padding: const EdgeInsets.only(top: 5),
                          child: Container(
                            width: 8,
                            height: 8,
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              color: WidgetLeaveCalendar.eventColor(
                                leaves[i].state,
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                leaves[i].description,
                                style: GoogleFonts.manrope(
                                  fontSize: 13,
                                  fontWeight: FontWeight.w600,
                                  color: titleColor,
                                ),
                              ),
                              const SizedBox(height: 2),
                              Text(
                                [
                                  _rangeLabel(leaves[i]),
                                  _daysLabel(leaves[i]),
                                ].where((part) => part.isNotEmpty).join(' · '),
                                style: GoogleFonts.manrope(
                                  fontSize: 11,
                                  color: detailColor,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}
