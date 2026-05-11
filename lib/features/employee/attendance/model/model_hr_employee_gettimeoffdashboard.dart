class TimeOffDashboardModel {
  final bool hasAccrualAllocation;
  final int allocationRequestAmount;

  TimeOffDashboardModel({
    required this.hasAccrualAllocation,
    required this.allocationRequestAmount,
  });

  factory TimeOffDashboardModel.fromJson(Map<String, dynamic> json) {
    return TimeOffDashboardModel(
      hasAccrualAllocation: json['has_accrual_allocation'] ?? false,
      allocationRequestAmount: json['allocation_request_amount'] ?? 0,
    );
  }
}

class AllocationItem {
  final String leaveType;
  final LeaveData data;
  final bool active;
  final int id;

  AllocationItem({
    required this.leaveType,
    required this.data,
    required this.active,
    required this.id,
  });

  factory AllocationItem.fromList(List<dynamic> list) {
    return AllocationItem(
      leaveType: list[0] ?? '',
      data: LeaveData.fromJson(list[1]),
      active: list[2] ?? false,
      id: list[3] ?? 0,
    );
  }
}

class LeaveData {
  final double remainingLeaves;
  final double virtualRemainingLeaves;
  final double maxLeaves;
  final double accrualBonus;
  final double leavesTaken;
  final double virtualLeavesTaken;
  final double leavesRequested;
  final double leavesApproved;
  final int employeeCompany;
  final String requestUnit;
  final String icon;
  final bool allowsNegative;
  final int maxAllowedNegative;

  LeaveData({
    required this.remainingLeaves,
    required this.virtualRemainingLeaves,
    required this.maxLeaves,
    required this.accrualBonus,
    required this.leavesTaken,
    required this.virtualLeavesTaken,
    required this.leavesRequested,
    required this.leavesApproved,
    required this.employeeCompany,
    required this.requestUnit,
    required this.icon,
    required this.allowsNegative,
    required this.maxAllowedNegative,
  });

  factory LeaveData.fromJson(Map<String, dynamic> json) {
    return LeaveData(
      remainingLeaves: (json['remaining_leaves'] ?? 0).toDouble(),
      virtualRemainingLeaves: (json['virtual_remaining_leaves'] ?? 0)
          .toDouble(),
      maxLeaves: (json['max_leaves'] ?? 0).toDouble(),
      accrualBonus: (json['accrual_bonus'] ?? 0).toDouble(),
      leavesTaken: (json['leaves_taken'] ?? 0).toDouble(),
      virtualLeavesTaken: (json['virtual_leaves_taken'] ?? 0).toDouble(),
      leavesRequested: (json['leaves_requested'] ?? 0).toDouble(),
      leavesApproved: (json['leaves_approved'] ?? 0).toDouble(),
      employeeCompany: json['employee_company'] ?? 0,
      requestUnit: json['request_unit'] ?? '',
      icon: json['icon'] ?? '',
      allowsNegative: json['allows_negative'] ?? false,
      maxAllowedNegative: json['max_allowed_negative'] ?? 0,
    );
  }
}
