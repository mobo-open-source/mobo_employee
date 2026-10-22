import 'package:flutter/material.dart';
import 'package:hugeicons/hugeicons.dart';
import 'package:mobo_employees/core/const/all_design.dart';
import 'package:mobo_employees/features/employee/leave/model/model_time_off_balance.dart';
import 'package:mobo_employees/features/manager/manager_approvals/widgets/widget_card.dart';

/// The row of cards atop Odoo's Time Off dashboard: one per time off type
/// the employee has (named as in the database), then a "Pending" card.
class TimeOffBalanceCards extends StatelessWidget {
  final List<TimeOffBalance> balances;
  final int pendingCount;

  /// What [pendingCount] counts, e.g. "Allocation requests".
  final String pendingSubtitle;

  const TimeOffBalanceCards({
    super.key,
    required this.balances,
    required this.pendingCount,
    required this.pendingSubtitle,
  });

  static const double _cardWidth = 160;

  static List<Color> get _palette => [
    AppColors.colorC03355,
    AppColors.Color0095FF,
    AppColors.color22C55E,
    AppColors.colorF59E0B,
  ];

  @override
  Widget build(BuildContext context) {
    final cards = <Widget>[
      for (var i = 0; i < balances.length; i++)
        DashboardStatCard(
          color: _palette[i % _palette.length],
          icon: HugeIcons.strokeRoundedUmbrella,
          count: balances[i].amountLabel,
          title: balances[i].name,
          titleMaxLines: 2,
          subtitle: balances[i].subtitle,
        ),
      DashboardStatCard(
        color: AppColors.colorFFCC3D,
        icon: HugeIcons.strokeRoundedTimeQuarter,
        count: pendingCount.toString(),
        title: "Pending",
        subtitle: pendingSubtitle,
      ),
    ];

    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: IntrinsicHeight(
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            for (var i = 0; i < cards.length; i++) ...[
              if (i > 0) const SizedBox(width: 8),
              SizedBox(width: _cardWidth, child: cards[i]),
            ],
          ],
        ),
      ),
    );
  }
}
