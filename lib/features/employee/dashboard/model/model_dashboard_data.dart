import 'dart:typed_data';
import 'package:mobo_employees/features/employee/dashboard/model/model_hr_leave_dashboard.dart';

class DashboardModel {
  /// User
  final String userName;
  final String greetings;
  final Uint8List? userImageBytes;

  /// Attendance
  final bool isCheckedIn;
  final String currentTime;
  final bool isCheckInOutLoading;

  /// Quick overview
  final double leaveBalance;
  final int leaveRequestCount;
  final double yesterdayWorkingHours;
  final String? nextLeaveDate;

  /// Recent Activity
  final HrLeave? recentLeave;

  /// UI state
  final bool isLoading;

  const DashboardModel({
    required this.userName,
    required this.greetings,
    required this.isCheckedIn,
    required this.currentTime,
    required this.isCheckInOutLoading,
    required this.leaveBalance,
    required this.leaveRequestCount,
    required this.yesterdayWorkingHours,
    required this.isLoading,
    this.nextLeaveDate,
    this.recentLeave,
    this.userImageBytes,
  });

  /// Initial / loading-safe state
  factory DashboardModel.initial() {
    return DashboardModel.fromJson(const {});
  }

  /// JSON → Model (NULL SAFE)
  factory DashboardModel.fromJson(Map<String, dynamic> json) {
    return DashboardModel(
      userName: json['userName'] ?? "-",
      greetings: json['greetings'] ?? "",
      isCheckedIn: json['isCheckedIn'] ?? false,
      currentTime: json['currentTime'] ?? "--:--",
      isCheckInOutLoading: json['isCheckInOutLoading'] ?? false,
      leaveBalance: (json['leaveBalance'] as num?)?.toDouble() ?? 0,
      leaveRequestCount: json['leaveRequestCount'] ?? 0,
      yesterdayWorkingHours:
          (json['yesterdayWorkingHours'] as num?)?.toDouble() ?? 0,
      nextLeaveDate: json['nextLeaveDate'],
      recentLeave: json['recentLeave'] is HrLeave
          ? json['recentLeave'] as HrLeave
          : null,

      userImageBytes: json['userImageBytes'],
      isLoading: json['isLoading'] ?? true,
    );
  }

  /// Model → JSON
  Map<String, dynamic> toJson() {
    return {
      'userName': userName,
      'greetings': greetings,
      'isCheckedIn': isCheckedIn,
      'currentTime': currentTime,
      'isCheckInOutLoading': isCheckInOutLoading,
      'leaveBalance': leaveBalance,
      'leaveRequestCount': leaveRequestCount,
      'yesterdayWorkingHours': yesterdayWorkingHours,
      'nextLeaveDate': nextLeaveDate,
      'recentLeave': recentLeave?.toJson(),
      'userImageBytes': userImageBytes,
      'isLoading': isLoading,
    };
  }

  /// UI helpers
  String get recentLeaveTitle =>
      recentLeave?.holidayStatusName ?? "No Recent Leave";

  String get recentLeaveSubtitle => recentLeave == null
      ? "No recent leave activity"
      : "Your Leave request $stateText";

  String get stateText => recentLeave?.state ?? "";

  bool get hasRecentLeave => recentLeave != null;
}
