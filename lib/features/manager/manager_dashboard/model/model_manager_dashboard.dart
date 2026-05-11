import 'dart:typed_data';

class ModelManagerDashboard {
  final ManagerUserModel user;
  final ManagerOverviewModel overview;
  final ManagerTodayReportModel todayReport;

  ModelManagerDashboard({
    required this.user,
    required this.overview,
    required this.todayReport,
  });

  factory ModelManagerDashboard.empty() {
    return ModelManagerDashboard(
      user: ManagerUserModel.empty(),
      overview: ManagerOverviewModel.empty(),
      todayReport: ManagerTodayReportModel.empty(),
    );
  }
}

class ManagerUserModel {
  final int? employeeId;
  final String name;
  final Uint8List? profileImage;
  final String greetings;

  ManagerUserModel({
    required this.employeeId,
    required this.name,
    required this.profileImage,
    required this.greetings,
  });

  factory ManagerUserModel.empty() {
    return ManagerUserModel(
      employeeId: null,
      name: "",
      profileImage: null,
      greetings: "",
    );
  }
}

class ManagerOverviewModel {
  final int totalEmployees;
  final int todayAttendance;
  final int todayLeaves;
  final int leaveRequests;

  ManagerOverviewModel({
    required this.totalEmployees,
    required this.todayAttendance,
    required this.todayLeaves,
    required this.leaveRequests,
  });

  factory ManagerOverviewModel.empty() {
    return ManagerOverviewModel(
      totalEmployees: 0,
      todayAttendance: 0,
      todayLeaves: 0,
      leaveRequests: 0,
    );
  }
}

class ManagerTodayReportModel {
  final int lateCheckIns;
  final int payslipsGenerated;
  final int newLeaveRequestsForToday;

  ManagerTodayReportModel({
    required this.lateCheckIns,
    required this.payslipsGenerated,
    required this.newLeaveRequestsForToday,
  });

  factory ManagerTodayReportModel.empty() {
    return ManagerTodayReportModel(
      lateCheckIns: 0,
      payslipsGenerated: 0,
      newLeaveRequestsForToday: 0,
    );
  }
}
