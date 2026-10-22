/// One card of Odoo's Time Off dashboard: the current employee's balance for
/// a single time off type, as returned by `get_allocation_data_request`
/// (`hr.leave.type` on 17/18, `hr.work.entry.type` on 20) or the
/// `allocation_data` of `hr.employee.get_time_off_dashboard_data` (19+).
///
/// Every version returns entries shaped `[name, data, requires_allocation,
/// type_id]`, one per type the employee actually has — never a fixed list,
/// so types are shown under whatever name the database gives them.
class TimeOffBalance {
  final int typeId;
  final String name;
  final bool requiresAllocation;

  /// What Odoo's card shows: the days/hours still available for types that
  /// require an allocation, the amount taken for the others.
  final double amount;
  final bool isHours;

  /// Expiry of the allocation expiring first, already formatted by Odoo in
  /// the user's language; `null` when it doesn't expire.
  final String? validity;

  const TimeOffBalance({
    required this.typeId,
    required this.name,
    required this.requiresAllocation,
    required this.amount,
    required this.isHours,
    required this.validity,
  });

  static TimeOffBalance? fromDashboardEntry(dynamic entry) {
    if (entry is! List || entry.length < 4 || entry[1] is! Map) return null;
    final data = entry[1] as Map;

    /// Selection('yes'/'no') up to 18, boolean afterwards.
    final requiresAllocation = entry[2] == true || entry[2] == 'yes';
    final amount = requiresAllocation
        ? data['virtual_remaining_leaves']
        : data['virtual_leaves_taken'];
    final validity = data['closest_allocation_expire'];

    return TimeOffBalance(
      typeId: entry[3] is int ? entry[3] : 0,
      name: entry[0]?.toString() ?? '',
      requiresAllocation: requiresAllocation,
      amount: amount is num ? amount.toDouble() : 0,
      /// Odoo 20 renamed request_unit to unit_of_measure
      isHours: (data['unit_of_measure'] ?? data['request_unit']) == 'hour',
      validity: requiresAllocation && validity is String && validity.isNotEmpty
          ? validity
          : null,
    );
  }

  /// The figure as Odoo's card prints it: `h:mm` for hour-based types,
  /// otherwise a number with up to two decimals.
  String get amountLabel {
    if (isHours) {
      final totalMinutes = (amount.abs() * 60).round();
      final sign = amount < 0 ? '-' : '';
      final minutes = (totalMinutes % 60).toString().padLeft(2, '0');
      return '$sign${totalMinutes ~/ 60}:$minutes';
    }
    if (amount == amount.roundToDouble()) return amount.toInt().toString();
    return amount.toStringAsFixed(2).replaceFirst(RegExp(r'0+$'), '');
  }

  /// The line under the type name on Odoo's card.
  String get subtitle {
    if (!requiresAllocation) return 'Taken';
    return validity != null ? 'Validity $validity' : 'Available';
  }
}

/// The figures behind Odoo's Time Off dashboard for the current employee.
class TimeOffDashboard {
  final List<TimeOffBalance> balances;

  /// Odoo's "Pending Allocations" card: the employee's own allocation
  /// requests still waiting for approval.
  final int pendingAllocations;

  const TimeOffDashboard({
    required this.balances,
    required this.pendingAllocations,
  });

  static const empty = TimeOffDashboard(balances: [], pendingAllocations: 0);
}
