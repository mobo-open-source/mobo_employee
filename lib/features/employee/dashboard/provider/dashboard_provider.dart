import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';
import 'package:intl/intl.dart';
import 'package:flutter/material.dart';
import 'package:hugeicons/hugeicons.dart';
import 'package:mobo_employees/core/services/connectivity_service.dart';
import 'package:mobo_employees/core/theme/app_theme.dart';
import 'package:mobo_employees/core/services/odoo_session_manager.dart';
import 'package:mobo_employees/features/employee/dashboard/model/model_dashboard_data.dart';
import 'package:mobo_employees/features/employee/dashboard/model/model_hr_leave_dashboard.dart';
import 'package:mobo_employees/features/employee/dashboard/service/administrator_dashboard_service.dart';
import 'package:mobo_employees/shared/services/payslip_service.dart';
import 'package:odoo_rpc/odoo_rpc.dart';

import 'package:shared_preferences/shared_preferences.dart';

import '../../../../widgets/snackbar_widgets.dart';

class DashboardProvider extends ChangeNotifier {
  DashboardModel dashboard = DashboardModel.initial();

  bool isDashboardLoading = true;
  bool isDashboardNewDataLoading = false;
  bool _isDisposed = false;
  bool isAttendanceCheckedIn = false;
  bool _initialized = false;
  bool isCheckInOutLoading = false;
  bool isInitialized = false;

  /// Set when the last full load failed (e.g. server unreachable); the page
  /// shows it in place of the shimmer until a retry succeeds.
  Object? loadError;

  HrLeave? recentLeave;

  int? employeeId;
  int leaveRequestCount = 0;
  int? _lastRecentLeaveId;

  double leaveBalance = 0;
  double yesterdayWorkingHours = 0;

  Uint8List? userImageBytes;

  static const String _attendanceKey = 'is_Attendance_CheckedIn';
  static const String _checkInTimeKey = 'check_in_time';
  static const String _checkOutTimeKey = 'check_out_time';

  String userName = "";
  String greetings = "";

  /// Date of the next public holiday ("Today" while one is on), and its name.
  String? nextLeaveDate;
  String? nextHolidayName;
  String? checkInn;
  String? checkOut;
  String currentTime = "";

  DateTime? checkInDateTime;
  DateTime? checkOutDateTime;

  /// Payslip figures, or null when Payroll isn't installed or the user may
  /// not read payslips (the dashboard hides its payslip cards then).
  EmployeePayslipSummary? payslipSummary;

  /// Whether the employee's last attendance was checked out today.
  bool get isCheckedOutToday {
    final out = checkOutDateTime;
    if (isAttendanceCheckedIn || out == null) return false;
    final now = DateTime.now();
    return out.year == now.year && out.month == now.month && out.day == now.day;
  }
  double workedHoursTillNow = 0;

  Timer? _timer;
  Timer? _recentLeaveTimer;

  final today = DateTime.now();

  late final startOfMonth = DateTime(today.year, today.month, 1);
  late final endOfMonth = DateTime(today.year, today.month + 1, 0);

  String formatDate(DateTime d) =>
      "${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}";

  String getFormattedTime() {
    return DateFormat('hh:mm a').format(DateTime.now());
  }

  void safeNotify() {
    if (!_isDisposed) notifyListeners();
  }

  String formatToMonthDay(String date) {
    return DateFormat('MMM dd').format(DateTime.parse(date));
  }

  Future<dynamic> _callKw(Map<String, dynamic> params) async {
    return await OdooSessionManager.callKwWithCompany(params);
  }

  void startClock() {
    _timer?.cancel();

    currentTime = DateFormat('hh:mm a').format(DateTime.now());

    _timer = Timer.periodic(const Duration(seconds: 1), (_) {
      currentTime = DateFormat('hh:mm a').format(DateTime.now());
      calculateWorkedHoursTillNow();
      safeNotify();
    });
  }

  Future<void> init() async {
    if (_initialized) return;
    await loadCheckInState();
    _initialized = true;
  }

  Future<void> loadDashboardOnce(BuildContext context) async {
    if (isInitialized) return;

    isInitialized = true;
    isDashboardLoading = true;
    safeNotify();

    await init();

    final session = await OdooSessionManager.getCurrentSession();
    if (session?.userId == null) {
      isDashboardLoading = false;
      safeNotify();
      return;
    }

    await fetchUserDetails(session!.userId!);
    setGreetings();

    await fetchNextPublicHoliday();
    await fetchLeaveBalance(session.userId!);
    await fetchLeaveRequestCount();
    await fetchYesterdayWorkingHours();
    await fetchRecentLeave();
    // Reconcile the locally cached check-in flag with the server's actual
    // attendance state — it may have changed from another device/admin
    // action while the app was closed.
    await getAttendeeState();

    buildDashboardModel();

    isDashboardLoading = false;
    safeNotify();
    startRecentLeaveWatcher();
  }

  void startRecentLeaveWatcher() {
    _recentLeaveTimer?.cancel();

    _recentLeaveTimer = Timer.periodic(const Duration(seconds: 30), (_) async {
      if (employeeId == null) return;
      try {
        final latest = await AdministratorDashboardService.fetchLatestLeave(
          employeeId: employeeId,
        );
        if (latest == null) return;
        if (_lastRecentLeaveId != latest.id) {
          recentLeave = latest;
          _lastRecentLeaveId = latest.id;
          buildDashboardModel();
          safeNotify();
        }
      } catch (_) {
        // Background poll; the next tick tries again.
      }
    });
  }

  String formatPrettyDateTime(String odooDateTime) {
    final dt = DateTime.parse(odooDateTime).toLocal();
    return DateFormat("MMM d, h:mm a").format(dt);
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

  String cleanedError(String error) {
    final errorMessage = error
        .toString()
        .split("message:")
        .last
        .split(",")
        .first
        .trim();
    return errorMessage;
  }

  Future<void> getAttendeeState() async {
    try {
      final response = await AdministratorDashboardService()
          .getAttendanceState();

      final state = response['attendance_state'];
      final prefs = await SharedPreferences.getInstance();

      if (state == "checked_in") {
        isAttendanceCheckedIn = true;
        final lastCheckInStr = response['last_check_in'];

        if (lastCheckInStr != null) {
          final lastCheckIn = DateTime.parse("${lastCheckInStr}Z").toLocal();
          checkInDateTime = lastCheckIn;
          checkInn = DateFormat("hh:mm a").format(lastCheckIn);
          currentTime = checkInn!;
          await prefs.setString(_checkInTimeKey, lastCheckIn.toIso8601String());
          notifyListeners();
        }
        await prefs.setBool(_attendanceKey, true);
      } else if (state == "checked_out") {
        isAttendanceCheckedIn = false;
        await prefs.setBool(_attendanceKey, false);
        // The response only carries the last check-in, which used to be
        // shown as the check-out time; read the real one.
        final lastCheckOut = employeeId == null
            ? null
            : await AdministratorDashboardService.fetchLastCheckOut(
                employeeId!,
              );
        checkOutDateTime = lastCheckOut;
        if (lastCheckOut != null) {
          checkOut = DateFormat("hh:mm a").format(lastCheckOut);
          await prefs.setString(
            _checkOutTimeKey,
            lastCheckOut.toIso8601String(),
          );
        } else {
          checkOut = null;
          await prefs.remove(_checkOutTimeKey);
        }
        notifyListeners();
      }
    } catch (e) {
      if (ConnectivityService.isConnectivityError(e)) rethrow;
    }
  }

  /// Check In function
  Future<void> performCheckIn({required BuildContext context}) async {
    if (employeeId == null || isCheckInOutLoading) return;
    try {
      isCheckInOutLoading = true;
      safeNotify();

      // The check-in/out endpoint only toggles whatever state the server
      // is currently in, so a stale local flag could make this call
      // actually check the user OUT. Re-sync from the server first and
      // bail out if we're already checked in rather than blindly toggling.
      await getAttendeeState();
      if (isAttendanceCheckedIn) {
        CustomSnackbar.showError(context, "You are already checked in.");
        return;
      }

      final success = await AdministratorDashboardService.checkIn(employeeId!);
      if (success) {
        final prefs = await SharedPreferences.getInstance();
        checkInDateTime = DateTime.now();
        isAttendanceCheckedIn = true;
        checkInn = DateFormat("hh:mm a").format(DateTime.now());
        currentTime = checkInn!;
        await prefs.setBool(_attendanceKey, true);
        await prefs.setString(
          _checkInTimeKey,
          checkInDateTime!.toIso8601String(),
        );
        await prefs.remove(_checkOutTimeKey);
        checkOutDateTime = null;
        CustomSnackbar.showSuccess(context, "Checked Inn at $checkInn");
      }
    } catch (e) {
      String errorMessage = "Something went wrong";
      if (e is OdooException) {
        final errorString = e.toString();

        if (errorString.contains("AccessError")) {
          errorMessage =
              "Permission denied: You don’t have access to perform check-out.";
        }
        else if (errorString.contains("Expected singleton")) {
          errorMessage =
              "Check-out failed: No employee record linked to your account.";
        } else if (errorString.contains("attendance")) {
          errorMessage = cleanedError(e.toString());
        }
        else if (e.message.isNotEmpty) {
          errorMessage = e.message;
        }
      }
      CustomSnackbar.showError(context, cleanedError(errorMessage));
    } finally {
      isCheckInOutLoading = false;
      safeNotify();
    }
  }

  /// CheckInn Status Cehck
  Future<void> loadCheckInState() async {
    final prefs = await SharedPreferences.getInstance();

    isAttendanceCheckedIn = prefs.getBool(_attendanceKey) ?? false;

    final checkInStored = prefs.getString(_checkInTimeKey);
    final checkOutStored = prefs.getString(_checkOutTimeKey);

    if (checkInStored != null) {
      checkInDateTime = DateTime.parse(checkInStored);
      checkInn = DateFormat('hh:mm a').format(checkInDateTime!);
      currentTime = checkInn!;
    }

    if (checkOutStored != null) {
      final outTime = DateTime.parse(checkOutStored);
      checkOutDateTime = outTime;
      checkOut = DateFormat('hh:mm a').format(outTime);
    }

    calculateWorkedHoursTillNow();
    safeNotify();
  }

  void calculateWorkedHoursTillNow() {
    if (!isAttendanceCheckedIn || checkInDateTime == null) {
      workedHoursTillNow = 0;
      return;
    }

    final now = DateTime.now();
    final duration = now.difference(checkInDateTime!);

    workedHoursTillNow = duration.inMinutes / 60;

    safeNotify();
  }

  /// Check Out function
  Future<void> performCheckOut({required BuildContext context}) async {
    if (employeeId == null || isCheckInOutLoading) return;

    try {
      isCheckInOutLoading = true;
      safeNotify();

      // See performCheckIn: re-sync from the server before toggling so a
      // stale local flag can't cause this call to actually check-in.
      await getAttendeeState();
      if (!isAttendanceCheckedIn) {
        CustomSnackbar.showError(context, "You are not currently checked in.");
        return;
      }

      final success = await AdministratorDashboardService.checkOut(employeeId!);
      if (success) {
        final prefs = await SharedPreferences.getInstance();

        isAttendanceCheckedIn = false;
        checkOutDateTime = DateTime.now();
        checkOut = DateFormat("hh:mm a").format(checkOutDateTime!);
        currentTime = checkOut!;

        await prefs.setBool(_attendanceKey, false);
        await prefs.setString(
          _checkOutTimeKey,
          DateTime.now().toIso8601String(),
        );
        await prefs.remove(_checkInTimeKey);
        CustomSnackbar.showSuccess(context, "Checked Out at $checkOut");
      }
    } catch (e) {
      String errorMessage = "Something went wrong";
      if (e is OdooException) {
        final errorString = e.toString();

        if (errorString.contains("AccessError")) {
          errorMessage =
              "Permission denied: You don’t have access to perform check-out.";
        }
        else if (errorString.contains("Expected singleton")) {
          errorMessage =
              "Check-out failed: No employee record linked to your account.";
        }
        else if (errorString.contains("attendance")) {
          errorMessage = "You are not currently checked in.";
        }
        else if (e.message.isNotEmpty) {
          errorMessage = e.message;
        }
      }
      CustomSnackbar.showError(context, cleanedError(errorMessage));
    } finally {
      isCheckInOutLoading = false;
      safeNotify();
    }
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
    userName = users.first['name'] ?? "-";
    final img = users.first['image_1920'];
    userImageBytes = (img is String && img.isNotEmpty)
        ? base64Decode(img)
        : null;
    await fetchEmployeeIdFromUser(userId);
    safeNotify();
  }

  /// Odoo format time
  String formatOdooDateTime(DateTime d) {
    return "${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')} "
        "00:00:00";
  }

  /// Next public holiday, from the holidays set in Odoo (Working Schedules →
  /// Public Holidays). `hr.leave.get_unusual_days`, used before, flags every
  /// non-working day, so the card mostly showed the coming weekend.
  Future<void> fetchNextPublicHoliday() async {
    try {
      final holiday = await AdministratorDashboardService.fetchNextPublicHoliday(
        employeeId: employeeId,
      );
      if (holiday == null) {
        nextLeaveDate = null;
        nextHolidayName = null;
      } else {
        final today = DateTime.now();
        final startDay = DateTime(
          holiday.start.year,
          holiday.start.month,
          holiday.start.day,
        );
        nextLeaveDate =
            startDay.isAfter(DateTime(today.year, today.month, today.day))
            ? DateFormat('MMM dd').format(startDay)
            : 'Today';
        nextHolidayName = holiday.name.isEmpty ? null : holiday.name;
      }
      safeNotify();
    } catch (e) {
      if (ConnectivityService.isConnectivityError(e)) rethrow;
      nextLeaveDate = null;
      nextHolidayName = null;
      safeNotify();
    }
  }

  /// Payslip cards' figures; see [payslipSummary].
  Future<void> fetchPayslipSummary() async {
    final id = employeeId;
    payslipSummary = id == null
        ? null
        : await PayslipService.fetchEmployeeSummary(id);
    safeNotify();
  }

  /// Recent Leave Status
  Future<void> fetchRecentLeave() async {
    try {
      recentLeave = await AdministratorDashboardService.fetchLatestLeave(
        employeeId: employeeId,
      );
      _lastRecentLeaveId = recentLeave?.id;
      safeNotify();
    } catch (e) {
      if (ConnectivityService.isConnectivityError(e)) rethrow;
      recentLeave = null;
    }
  }

  Future<void> fetchLeaveRequestCount() async {
    try {
      leaveRequestCount =
          await AdministratorDashboardService.fetchLeaveRequestCount();
      safeNotify();
    } catch (e) {
      if (ConnectivityService.isConnectivityError(e)) rethrow;
      leaveRequestCount = 0;
      safeNotify();
    }
  }

  void buildDashboardModel() {
    dashboard = DashboardModel.fromJson({
      'userName': userName,
      'greetings': greetings,
      'userImageBytes': userImageBytes,
      'isCheckedIn': isAttendanceCheckedIn,
      'currentTime': currentTime,
      'isCheckInOutLoading': isCheckInOutLoading,
      'leaveBalance': leaveBalance,
      'leaveRequestCount': leaveRequestCount,
      'yesterdayWorkingHours': yesterdayWorkingHours,
      'nextLeaveDate': nextLeaveDate,
      'recentLeave': recentLeave,
      'isLoading': false,
    });
    isDashboardLoading = false;
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
    userName = "-";
    userImageBytes = null;
    greetings = "";
    isDashboardNewDataLoading = false;
    notifyListeners();
  }

  /// Fetch Balance Leave
  Future<void> fetchLeaveBalance(int userId) async {
    try {
      final employee =
          await AdministratorDashboardService.fetchEmployeeByUserId(userId);

      if (employee != null) {
        employeeId = employee.id;

        leaveBalance =
            double.tryParse(employee.allocationRemainingDisplay ?? "0") ?? 0;
      } else {
        leaveBalance = 0;
      }

      safeNotify();
    } catch (e) {
      if (ConnectivityService.isConnectivityError(e)) rethrow;
      leaveBalance = 0;
      safeNotify();
    }
  }


  /// Re-reads the leave figures on the dashboard — pending request count,
  /// latest request, balance — in place, without the loading shimmer, so a
  /// request submitted, approved or refused since the last visit shows up.
  Future<void> refreshLeaveStats() async {
    final session = await OdooSessionManager.getCurrentSession();
    final userId = session?.userId;
    if (userId == null) return;

    try {
      await Future.wait([
        fetchLeaveRequestCount(),
        fetchRecentLeave(),
        fetchLeaveBalance(userId),
      ]);
    } catch (_) {
      // In-place refresh: figures that couldn't be re-read (server
      // unreachable) keep their last loaded values.
    }
    buildDashboardModel();
    safeNotify();
  }

  /// Refresh Dashboard
  ///
  /// The first call loads everything behind the shimmer. Later non-forced
  /// calls (returning to the dashboard tab) only refresh the leave figures
  /// via [refreshLeaveStats]; pull-to-refresh passes [isRefresh] to reload
  /// it all. After a failed load, every call retries the full load.
  Future<void> refreshDashboard({bool isRefresh = false}) async {
    if (isRefresh == false) {
      if (isDashboardNewDataLoading && loadError == null) {
        await refreshLeaveStats();
        return;
      }
    }

    isDashboardLoading = true;
    isDashboardNewDataLoading = true;
    loadError = null;
    dashboard = DashboardModel.initial();
    safeNotify();

    clearDashboard();

    try {
      final session = await OdooSessionManager.getCurrentSession();
      if (session?.userId != null) {
        await fetchUserDetails(session!.userId!);
        setGreetings();
        safeNotify();
        await fetchNextPublicHoliday();
        await fetchPayslipSummary();
        await fetchLeaveBalance(session.userId!);
        await fetchYesterdayWorkingHours();

        await fetchLeaveRequestCount();

        await fetchYesterdayWorkingHours();
        await fetchRecentLeave();
        await getAttendeeState();
        buildDashboardModel();
        startClock();
      }
    } catch (e) {
      loadError = e;
    } finally {
      isDashboardLoading = false;
      isDashboardNewDataLoading = true;
      safeNotify();
    }
  }

  ///Productive Hours
  Future<void> fetchYesterdayWorkingHours() async {
    try {
      final session = await OdooSessionManager.getCurrentSession();
      final emp = await OdooSessionManager.callKwWithCompany({
        'model': 'hr.employee',
        'method': 'search_read',
        'args': [],
        'kwargs': {
          'domain': [
            ['user_id', '=', session!.userId],
          ],
          'fields': ['id', 'name'],
          'limit': 1,
        },
      });
      final attendance =
          await AdministratorDashboardService.fetchEmployeeAttendance(
            emp[0]['id'],
          );

      if (!attendance.hasData) {
        yesterdayWorkingHours = 0;
        safeNotify();
        return;
      }

      final now = DateTime.now();
      final yesterday = DateTime(
        now.year,
        now.month,
        now.day,
      ).subtract(const Duration(days: 1));

      double totalHours = 0;

      for (final record in attendance.records) {
        if (record.checkIn == null) continue;

        final checkInLocal = record.checkIn!.toLocal();

        final recordDate = DateTime(
          checkInLocal.year,
          checkInLocal.month,
          checkInLocal.day,
        );

        if (recordDate == yesterday) {
          totalHours += record.workedHours;
        }
      }

      yesterdayWorkingHours = totalHours;
      notifyListeners();
      safeNotify();
    } catch (e) {
      if (ConnectivityService.isConnectivityError(e)) rethrow;
      yesterdayWorkingHours = 0;
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

  String getLeaveStatusText(String state) {
    switch (state) {
      case 'validate':
        return 'Approved';
      case 'refuse':
        return 'Rejected';
      case 'confirm':
      case 'validate1':
        return 'Pending';
      default:
        return 'Unknown';
    }
  }

  /// Badge colour of a time off in [state] (`hr.leave.state`).
  Color getLeaveStatusColor(String state) => StatusColors.forState(state);

  String getWorkedDuration() {
    if (!isAttendanceCheckedIn || checkInDateTime == null) return '';

    final now = DateTime.now();
    final diff = now.difference(checkInDateTime!);

    final hours = diff.inHours;
    final minutes = diff.inMinutes % 60;

    return '${hours.toString().padLeft(2, '0')}h '
        '${minutes.toString().padLeft(2, '0')}m';
  }

  /// Clear while Logout
  Future<void> clearOnLogout() async {
    _timer?.cancel();
    _recentLeaveTimer?.cancel();
    _timer = null;
    _recentLeaveTimer = null;
    employeeId = null;
    dashboard = DashboardModel.initial();
    loadError = null;

    isDashboardLoading = false;
    isDashboardNewDataLoading = false;
    isAttendanceCheckedIn = false;
    isCheckInOutLoading = false;
    _initialized = true;

    userName = "-";
    greetings = "";
    userImageBytes = null;

    checkInDateTime = null;
    checkOutDateTime = null;
    checkInn = null;
    checkOut = null;
    currentTime = "";
    workedHoursTillNow = 0;

    leaveBalance = 0;
    leaveRequestCount = 0;
    yesterdayWorkingHours = 0;
    nextLeaveDate = null;
    nextHolidayName = null;
    payslipSummary = null;
    recentLeave = null;
    _lastRecentLeaveId = null;
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_attendanceKey);
    await prefs.remove(_checkInTimeKey);
    await prefs.remove(_checkOutTimeKey);

    safeNotify();
  }

  /// Dispose
  @override
  void dispose() {
    _timer?.cancel();
    _recentLeaveTimer?.cancel();
    _isDisposed = true;
    super.dispose();
  }
}
