import 'dart:convert';
import 'dart:ui';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:hugeicons/hugeicons.dart';
import 'package:intl/intl.dart';
import 'package:mobo_employees/core/services/odoo_session_manager.dart';
import 'package:mobo_employees/features/manager/manager_dashboard/model/model_manager_dashboard.dart';
import 'package:mobo_employees/features/manager/manager_dashboard/service/manager_dashboard_data_service.dart';
import 'package:mobo_employees/shared/services/payslip_service.dart';
import 'package:provider/provider.dart';

class ManagerDashboardProvider extends ChangeNotifier {
  bool isManagerDashboardLoading = true;
  bool isManagerDashboardDataLoading = false;
  bool _isDisposed = false;
  bool _initialized = false;
  bool isInitialized = false;

  /// Set when the last full load failed (e.g. server unreachable); the page
  /// shows it in place of the shimmer until a retry succeeds.
  Object? loadError;

  int? employeeId;

  /// The logged-in manager's own user id. Set by [fetchUserDetails].
  int? currentUserId;

  int leaveRequestCount = 0;
  int totalEmployeeCount = 0;
  int todayAttendanceCount = 0;
  int totalLeaveRequests = 0;
  int totalTodayLeaves = 0;
  int totalLeaveRequestsCountForToday = 0;
  int lateCheckInCount = 0;

  /// See [ManagerTodayReportModel.payslipsGenerated].
  int? payslipsGenerated;

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


  /// Set while [refreshTodayCounts] runs, so ticks don't overlap.
  bool _isRefreshingCounts = false;

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
    await _loadCounts();

    setGreetings();

    buildDashboardModel();

    isManagerDashboardLoading = false;
    // Set here, after everything else.
    isInitialized = true;

    safeNotify();
  }

  /// Reads the figures of the cards and Today's Reports — everything that
  /// moves during the day. Assigns them only once all have been read, so a
  /// failure part-way never leaves a mix of old and new values.
  Future<void> _loadCounts() async {
    final counts = await Future.wait<int>([
      ManagerDashboardDataService.fetchTotalEmployeeCount(),
      ManagerDashboardDataService.fetchTodayAttendanceCount(),
      ManagerDashboardDataService.fetchLeaveRequestCount(),
      ManagerDashboardDataService.fetchTodayLeavesTotalCount(),
      ManagerDashboardDataService.fetchLeaveRequestCountForToday(),
      ManagerDashboardDataService.fetchLateCheckInCount(),
    ]);
    totalEmployeeCount = counts[0];
    todayAttendanceCount = counts[1];
    totalLeaveRequests = counts[2];
    totalTodayLeaves = counts[3];
    totalLeaveRequestsCountForToday = counts[4];
    lateCheckInCount = counts[5];
  }

  /// Re-reads the day's figures in place, without the loading shimmer, so
  /// check-ins, leave requests and approvals made since the last read show
  /// up: when returning to the dashboard, on app resume, and on a timer.
  /// If the server can't be reached the figures keep their last values.
  Future<void> refreshTodayCounts() async {
    if (currentUserId == null ||
        _isRefreshingCounts ||
        isManagerDashboardLoading) {
      return;
    }
    _isRefreshingCounts = true;
    try {
      await _loadCounts();
      buildDashboardModel();
    } catch (_) {
      // In-place refresh; the next one tries again.
    } finally {
      _isRefreshingCounts = false;
      safeNotify();
    }
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
        payslipsGenerated: payslipsGenerated,
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

  /// Pushes a profile edit (name/photo) made elsewhere in the app into the
  /// dashboard's greeting card, which otherwise keeps the values it fetched
  /// once at load time until the next full dashboard refresh.
  void applyProfileChange({String? name, Uint8List? imageBytes}) {
    if (name != null && name.trim().isNotEmpty) userName = name.trim();
    if (imageBytes != null) userImageBytes = imageBytes;
    buildDashboardModel();
    safeNotify();
  }

  /// Fetch user details
  Future<void> fetchUserDetails(int userId) async {
    currentUserId = userId;
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
        'domain': [
          ['user_id', '=', userId],
        ],
        'fields': ['id'],
        'limit': 1,
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
  ///
  /// Non-forced calls (returning to the dashboard tab) only re-read the
  /// day's figures in place via [refreshTodayCounts] once the dashboard has
  /// loaded; pull-to-refresh passes [isRefresh] to reload it all. After a
  /// failed load, every call retries the full load.
  Future<void> refreshDashboard({bool isRefresh = false}) async {
    if (isRefresh == false) {
      if (isManagerDashboardDataLoading && loadError == null) {
        await refreshTodayCounts();
        return;
      }
    }

    isManagerDashboardLoading = true;
    isManagerDashboardDataLoading = true;
    loadError = null;
    safeNotify();



    clearDashboard();

    try {
      final session = await OdooSessionManager.getCurrentSession();
      if (session?.userId != null) {
        await fetchUserDetails(session!.userId);
        await _loadCounts();
        payslipsGenerated = await PayslipService.fetchCountForMonth(
          month: DateTime.now(),
        );
        setGreetings();
        buildDashboardModel();
      }
    } catch (e) {
      loadError = e;
    } finally {
      isManagerDashboardLoading = false;
      isManagerDashboardDataLoading = true;
      safeNotify();
    }
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


    employeeId = null;
    userName = "";
    userImageBytes = null;
    greetings = "";
    currentTime = "";

    leaveRequestCount = 0;
    totalEmployeeCount = 0;
    todayAttendanceCount = 0;
    totalLeaveRequests = 0;
    totalTodayLeaves = 0;
    totalLeaveRequestsCountForToday = 0;
    lateCheckInCount = 0;
    payslipsGenerated = null;

    ManagerDashboardDataService.reset();

    isManagerDashboardLoading = false;
    isManagerDashboardDataLoading = false;
    _isRefreshingCounts = false;

    dashboard = ModelManagerDashboard.empty();
    loadError = null;

    isInitialized = false;
    _initialized = false;

    safeNotify();
  }



  /// Dispose
  @override
  void dispose() {
    _isDisposed = true;
    super.dispose();
  }
}
