import 'dart:convert';
import 'dart:ui';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:hugeicons/hugeicons.dart';
import 'package:intl/intl.dart';
import 'package:mobo_employees/core/services/odoo_session_manager.dart';
import 'package:mobo_employees/features/manager/manager_dashboard/model/model_manager_dashboard.dart';
import 'package:mobo_employees/features/manager/manager_dashboard/service/manager_dashboard_data_service.dart';
import 'package:provider/provider.dart';

class ManagerDashboardProvider extends ChangeNotifier {
  bool isManagerDashboardLoading = true;
  bool isManagerDashboardDataLoading = false;
  bool _isDisposed = false;
  bool _initialized = false;
  bool isInitialized = false;

  int? employeeId;
  int leaveRequestCount = 0;
  int totalEmployeeCount = 0;
  int todayAttendanceCount = 0;
  int totalLeaveRequests = 0;
  int totalTodayLeaves = 0;
  int totalLeaveRequestsCountForToday = 0;
  int lateCheckInCount = 0;

  int get totalEmployees => dashboard.overview.totalEmployees;
  int get todayAttendance => dashboard.overview.todayAttendance;

  bool get isInitialLoading =>
      isManagerDashboardLoading &&
      dashboard.overview.totalEmployees == 0 &&
      dashboard.user.name.isEmpty;

  Uint8List? userImageBytes;

  String userName = "";
  String greetings = "";
  String currentTime = "";


  List<Map<String, dynamic>> todayCalendarStartHours = [];
  List<Map<String, dynamic>> attendanceWithDayInfo = [];
  List<Map<String, dynamic>> employeesWithCalendar = [];

  bool isCalendarStartHourLoading = false;
  bool isAttendanceWithDayInfoLoading = false;

  Future<void> fetchTodayCalendarStartHours() async {
    isCalendarStartHourLoading = true;
    safeNotify();

    try {
      todayCalendarStartHours =
          await ManagerDashboardDataService.fetchTodayCalendarStartHours();
    } catch (e) {
      todayCalendarStartHours = [];
    }

    isCalendarStartHourLoading = false;
    safeNotify();
  }

  Future<void> fetchAttendanceWithDayInfo() async {
    isAttendanceWithDayInfoLoading = true;
    safeNotify();

    try {
      attendanceWithDayInfo =
          await ManagerDashboardDataService.fetchAttendanceWithDayInfo();
    } catch (e) {
      attendanceWithDayInfo = [];
    }

    isAttendanceWithDayInfoLoading = false;
    safeNotify();
  }

  Future<void> fetchEmployeesWithCalendar() async {
    try {
      employeesWithCalendar =
          await ManagerDashboardDataService.fetchEmployeesWithCalendar();
    } catch (e) {
      employeesWithCalendar = [];
    }
  }

  Future<void> calculateLateCheckInsForToday() async {
    int lateCount = 0;

    /// calendarId -> startHour
    final Map<int, double> calendarStartHourMap = {
      for (final c in todayCalendarStartHours) c['calendar_id']: c['hour_from'],
    };

    /// employeeId -> first check-in hour
    final Map<int, double> employeeFirstCheckInMap = {};

    for (final a in attendanceWithDayInfo) {
      final int empId = a['employee_id'];
      final String time = a['check_in_time']; /// HH:mm

      final h = int.parse(time.split(':')[0]);
      final m = int.parse(time.split(':')[1]);

      final hourValue = h + (m / 60);

      /// because records are ASC, first entry = first check-in
      employeeFirstCheckInMap.putIfAbsent(empId, () => hourValue);
    }

    for (final emp in employeesWithCalendar) {
      final int empId = emp['employee_id'];
      final int? calendarId = emp['calendar_id'];

      if (calendarId == null) continue;
      if (!calendarStartHourMap.containsKey(calendarId)) continue;
      if (!employeeFirstCheckInMap.containsKey(empId)) continue;

      final double startHour = calendarStartHourMap[calendarId]!;
      final double checkInHour = employeeFirstCheckInMap[empId]!;

      final bool isLate = checkInHour > startHour;

      if (isLate) lateCount++;
    }

    lateCheckInCount = lateCount;

    safeNotify();
  }


  final today = DateTime.now();

  late final startOfMonth = DateTime(today.year, today.month, 1);
  late final endOfMonth = DateTime(today.year, today.month + 1, 0);

  ModelManagerDashboard dashboard = ModelManagerDashboard.empty();

  void safeNotify() {
    if (!_isDisposed) notifyListeners();
  }



  Future<dynamic> _callKw(Map<String, dynamic> params) async {
    return await OdooSessionManager.callKwWithCompany(params);
  }

  Future<void> init() async {
    if (_initialized) return;
    _initialized = true;
  }

  Future<void> loadDashboardOnce(BuildContext context) async {
    if (isInitialized) return;

    isManagerDashboardLoading = true;
    safeNotify();



    await init();

    final session = await OdooSessionManager.getCurrentSession();
    if (session?.userId == null) {
      isManagerDashboardLoading = false;
      safeNotify();
      return;
    }


    await fetchUserDetails(session!.userId!);

    totalEmployeeCount =
        await ManagerDashboardDataService.fetchTotalEmployeeCount();
    todayAttendanceCount =
        await ManagerDashboardDataService.fetchTodayAttendanceCount();
    totalLeaveRequests =
        await ManagerDashboardDataService.fetchLeaveRequestCount();
    totalTodayLeaves =
        await ManagerDashboardDataService.fetchTodayLeavesTotalCount();
    totalLeaveRequestsCountForToday =
        await ManagerDashboardDataService.fetchLeaveRequestCountForToday();
    lateCheckInCount = 0;
    await fetchTodayCalendarStartHours();
    await fetchAttendanceWithDayInfo();
    await fetchEmployeesWithCalendar();
    await calculateLateCheckInsForToday();

    setGreetings();

    /// Build dashboard model ONCE
    buildDashboardModel();

    /// END initial loading
    isManagerDashboardLoading = false;
    isInitialized = true; /// SET HERE (AFTER EVERYTHING)

    safeNotify();
  }

  String formatPrettyDateTime(String odooDateTime) {
    final dt = DateTime.parse(odooDateTime).toLocal();
    return DateFormat("MMM d, h:mm a").format(dt);
  }

  int _safeInt(dynamic value) {
    if (value == null) return 0;
    if (value is bool) return value ? 1 : 0;
    if (value is int) return value;
    if (value is double) return value.toInt();
    if (value is String) return int.tryParse(value) ?? 0;
    return 0;
  }

  void buildDashboardModel() {
    dashboard = ModelManagerDashboard(
      user: ManagerUserModel(
        employeeId: employeeId,
        name: userName.isNotEmpty ? userName : "",
        profileImage: userImageBytes,
        greetings: greetings.isNotEmpty ? greetings : "",
      ),
      overview: ManagerOverviewModel(
        totalEmployees: _safeInt(totalEmployeeCount),
        todayAttendance: _safeInt(todayAttendanceCount),
        todayLeaves: _safeInt(totalTodayLeaves),
        leaveRequests: _safeInt(totalLeaveRequests),
      ),
      todayReport: ManagerTodayReportModel(
        lateCheckIns: _safeInt(lateCheckInCount),
        payslipsGenerated: 0,
        newLeaveRequestsForToday: _safeInt(totalLeaveRequestsCountForToday),
      ),
    );
  }

  /// Greetings
  void setGreetings() {
    final hour = DateTime.now().hour;
    greetings = hour < 12
        ? "Morning"
        : hour < 18
        ? "Afternoon"
        : "Evening";
  }

  /// Fetch user details
  Future<void> fetchUserDetails(int userId) async {
    final List users = await _callKw({
      'model': 'res.users',
      'method': 'search_read',
      'args': [],
      'kwargs': {
        'domain': [
          ['id', '=', userId],
        ],
        'fields': ['name', 'image_1920'],
      },
    });
    if (users.isEmpty) return;
    userName = users.first['name'] ?? "";
    final img = users.first['image_1920'];
    userImageBytes = (img is String && img.isNotEmpty)
        ? base64Decode(img)
        : null;
    await fetchEmployeeIdFromUser(userId);
    safeNotify();
  }

  /// Fetch Employee Id
  Future<void> fetchEmployeeIdFromUser(int userId) async {
    final result = await _callKw({
      'model': 'hr.employee',
      'method': 'search_read',
      'args': [],
      'kwargs': {
        'domain': [],
        'fields': ['id'],
      },
    });

    if (result is List && result.isNotEmpty) {
      employeeId = result.first['id'];
    } else {
      employeeId = null;
    }
  }

  /// Clear Dashboard
  void clearDashboard() {
    userName = "";
    userImageBytes = null;
    greetings = "";
    isManagerDashboardDataLoading = false;
    dashboard = ModelManagerDashboard.empty();
    notifyListeners();
  }

  /// Format time value .5 => :30
  String formatHourFromDouble(double hour) {
    final int h = hour.floor();
    final int minutes = ((hour - h) * 60).round();

    final String hh = h.toString().padLeft(2, '0');
    final String mm = minutes.toString().padLeft(2, '0');

    return "$hh:$mm";
  }

  /// Refresh Dashboard
  Future<void> refreshDashboard({bool isRefresh = false}) async {
    if (isRefresh == false) {
      if (isManagerDashboardDataLoading) return;
    }

    isManagerDashboardLoading = true;
    isManagerDashboardDataLoading = true;
    safeNotify();



    clearDashboard();

    try {
      final session = await OdooSessionManager.getCurrentSession();
      if (session?.userId != null) {
        await fetchUserDetails(session!.userId);
        totalEmployeeCount =
            await ManagerDashboardDataService.fetchTotalEmployeeCount();
        todayAttendanceCount =
            await ManagerDashboardDataService.fetchTodayAttendanceCount();
        totalLeaveRequests =
            await ManagerDashboardDataService.fetchLeaveRequestCount();
        totalTodayLeaves =
            await ManagerDashboardDataService.fetchTodayLeavesTotalCount();
        totalLeaveRequestsCountForToday =
            await ManagerDashboardDataService.fetchLeaveRequestCountForToday();
        await fetchTodayCalendarStartHours();
        await fetchAttendanceWithDayInfo();
        await fetchEmployeesWithCalendar();
        await calculateLateCheckInsForToday();
         setGreetings();
        buildDashboardModel();
      }
      isManagerDashboardLoading = false;
      isManagerDashboardDataLoading = true;
      safeNotify();
    } catch (e) {}
  }

  /// Icon Handle
  Widget iconHandle({required Color color}) {
    return HugeIcon(
      icon: HugeIcons.strokeRoundedUserCircle02,
      size: 35,
      color: color,
    );
  }

  /// Clear while Logout
  Future<void> clearOnManagerLogout() async {


    /// User data
    employeeId = null;
    userName = "";
    userImageBytes = null;
    greetings = "";
    currentTime = "";

    /// Counters
    leaveRequestCount = 0;
    totalEmployeeCount = 0;
    todayAttendanceCount = 0;
    totalLeaveRequests = 0;
    totalTodayLeaves = 0;
    totalLeaveRequestsCountForToday = 0;
    lateCheckInCount = 0;

    /// Lists
    todayCalendarStartHours.clear();
    attendanceWithDayInfo.clear();
    employeesWithCalendar.clear();

    /// Loading flags
    isManagerDashboardLoading = false;
    isManagerDashboardDataLoading = false;
    isCalendarStartHourLoading = false;
    isAttendanceWithDayInfoLoading = false;

    /// Dashboard model
    dashboard = ModelManagerDashboard.empty();

    /// Reset initialization flags
    isInitialized = false;
    _initialized = false;

    safeNotify();
  }



  /// Dispose
  @override
  void dispose() {
    _isDisposed = true;
    /// clearDashboard();
    super.dispose();
  }
}
