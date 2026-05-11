import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:mobo_employees/features/employee/attendance/model/model_hr_attendance_all_leaves.dart';
import 'package:mobo_employees/features/employee/attendance/model/model_hr_employee.dart';
import 'package:mobo_employees/features/employee/attendance/model/model_hr_employee_attendance.dart';
import 'package:mobo_employees/features/employee/attendance/model/model_hr_working_schedules.dart';
import 'package:mobo_employees/features/employee/attendance/model/model_leave_unusual_days.dart';
import 'package:mobo_employees/features/employee/attendance/service/administrator_attendance_service.dart';
import 'package:provider/provider.dart';

import '../../dashboard/provider/dashboard_provider.dart';

class AttendanceProvider extends ChangeNotifier {
  final Set<DateTime> unusualDates = {};
  final Set<DateTime> leaveDates = {};
  final Set<DateTime> holidayDates = {};
  final Set<DateTime> attendanceDates = {};
  final Set<String> loadedMonths = {};
  String _monthKey(DateTime d) => '${d.year}-${d.month}';

  String? checkInn;
  String? checkOut;

  DateTime calendarMonth = DateTime.now();
  final DateTime currentMonth = DateTime(
    DateTime.now().year,
    DateTime.now().month,
  );

  DateTime focusedDay = DateTime.now();
  DateTime? selectedDay;

  DateTime get normalizedFocusedMonth =>
      DateTime(focusedDay.year, focusedDay.month);

  int daysPresent = 0;
  int totalDaysInMonth = 0;

  void updateCalendarMonth(DateTime month) {
    calendarMonth = DateTime(month.year, month.month);
    notifyListeners();
  }

  int _monthlyLeaveCount = 0;
  int get monthlyLeaveCount => _monthlyLeaveCount;

  int _monthlyAttendanceCount = 0;
  int get monthlyAttendanceCount => _monthlyAttendanceCount;

  double _attendancePercentage = 0;
  double get attendancePercentage => _attendancePercentage;

  bool isLoading = false;
  bool isMonthlyLoading = false;
  bool isWorkingScheduleLoading = false;
  bool isInitialLoaded = false;
  bool hasLoadedOnce = false;

  int calendarAttendanceCount = 0;
  int calendarLeaveCount = 0;

  EmployeeModel? employeeModel;
  AttendanceEmployeeModel? attendanceEmployeeModel;

  ModelLeaveUnusualDays? modelLeaveUnusualDays;
  ModelHrWorkingSchedules? modelHrWorkingSchedules;

  DateTime selectedMonth = DateTime.now();

  void updateMonth(DateTime month) {
    selectedMonth = DateTime(month.year, month.month);
    notifyListeners();
  }

  changeInitialLoading() {
    isInitialLoaded = true;
    isLoading = false;
    hasLoadedOnce = true;
    notifyListeners();
  }

  final List<ModelHrAttendanceAllLeaves> allLeaves = [];

  DateTime _normalize(DateTime d) => DateTime(d.year, d.month, d.day);
  bool isUnusual(DateTime day) => unusualDates.contains(_normalize(day));
  bool isLeave(DateTime day) => leaveDates.contains(_normalize(day));
  bool isHoliday(DateTime day) => holidayDates.contains(_normalize(day));
  bool isPresent(DateTime day) =>
      attendanceDates.contains(DateTime(day.year, day.month, day.day));

  Future<void> refreshAttendance({
    required int employeeId,
    required DateTime month,
  }) async {


    if (hasLoadedOnce) return;

    isInitialLoaded = false;
    notifyListeners();

    try {
      await Future.wait([
        fetchEmployeeByEmployeeId(employeeId),
        fetchLeaveUnusualDays(),
        fetchAllLeaves(employeeId: employeeId),
        fetchCalendarHolidays(month: month),
        loadAttendanceDays(employeeId: employeeId, month: month),
        loadMonthlyLeaveCount(employeeId: employeeId, month: month),
        fetchDailyAttendenceCheckInCheckout(employeeId, DateTime.now()),
        loadMonthlyAttendanceCount(employeeId: employeeId, month: month),
      ]);
    } catch (e) {
    } finally {
      isInitialLoaded = true;
      hasLoadedOnce = true;
      notifyListeners();
    }
  }

  Future fetchDailyAttendenceCheckInCheckout(
    int employeeId,
    DateTime date,
  ) async {
    try {
      final result = await AdministratorAttendanceService().getDailyAttendance(
        employeeId,
        date,
      );

      if (result['first_check_in'] != null)
        checkInn = DateFormat("hh:mm a").format(result['first_check_in']);
      else
        checkInn = null;
      if (result['last_check_out'] != null)
        checkOut = DateFormat("hh:mm a").format(result['last_check_out']);
      else
        checkOut = null;
      notifyListeners();
    } catch (e) {}
  }

  Future<void> loadAttendanceDays({
    required int employeeId,
    required DateTime month,
  }) async {
    attendanceDates.clear();

    final days = await AdministratorAttendanceService.fetchMonthlyCheckInDates(
      employeeId: employeeId,
      month: month,
    );

    attendanceDates.addAll(days);
    notifyListeners();
  }

  void selectDay(DateTime day, DateTime focused, int employeeId) {
    selectedDay = day;
    focusedDay = focused;

    fetchDailyAttendenceCheckInCheckout(3, selectedDay!);

    notifyListeners();
  }

  DateTime _normalizeOdoo(DateTime d) {
    final utc = DateTime.utc(
      d.year,
      d.month,
      d.day,
      d.hour,
      d.minute,
      d.second,
    );
    final local = utc.toLocal();
    return DateTime(local.year, local.month, local.day);
  }



  Future<void> refreshCalendarMonth({
    required int employeeId,
    required DateTime month,
  }) async {
    final key = _monthKey(month);

    ///already fetched → DO NOTHING
    if (loadedMonths.contains(key)) {
      return;
    }
    loadedMonths.add(key);
    await fetchLeaveUnusualDays();
    await fetchAllLeaves(employeeId: employeeId);
    await fetchCalendarHolidays(month: month);
    await _loadCalendarAttendanceCount(employeeId: employeeId, month: month);
    notifyListeners();
  }

  Future<void> _loadCalendarAttendanceCount({
    required int employeeId,
    required DateTime month,
  }) async {
    calendarAttendanceCount =
        await AdministratorAttendanceService.fetchMonthlyAttendanceDays(
          employeeId: employeeId,
          month: month,
        );
  }

  Future<void> fetchLeaveUnusualDays() async {
    unusualDates.clear();

    final model = await AdministratorAttendanceService().fetchUnusualDays();
    if (model != null) {
      for (final record in model.records) {
        if (record.isUnusual) {
          unusualDates.add(_normalize(record.date));
        }
      }
    }
  }

  Future<void> loadMonthlyAttendanceCount({
    required int employeeId,
    required DateTime month,
  }) async {
    _monthlyAttendanceCount =
        await AdministratorAttendanceService.fetchMonthlyAttendanceDays(
          employeeId: employeeId,
          month: month,
        );

    _recalculateAttendance(DateTime.now());
    notifyListeners();
  }

  Future<void> fetchAllLeaves({required int? employeeId}) async {
    leaveDates.clear();
    allLeaves.clear();
    final leaves = await AdministratorAttendanceService.fetchAllLeaves(
      employeeId: employeeId,
    );
    for (final leave in leaves) {
      DateTime current = _normalize(leave.dateFrom);
      final end = _normalize(leave.dateTo);

      while (!current.isAfter(end)) {
        leaveDates.add(current);
        current = current.add(const Duration(days: 1));
      }
    }
  }

  Future<void> fetchCalendarHolidays({required DateTime month}) async {
    holidayDates.clear();
    final monthStart = DateTime(month.year, month.month, 1);
    final monthEnd = DateTime(month.year, month.month + 1, 0);

    final holidays = await AdministratorAttendanceService.fetchHolidays(
      month: month,
    );

    for (final h in holidays) {
      if (h.dateFrom == null || h.dateTo == null) continue;

      DateTime day = _normalizeOdoo(h.dateFrom!);
      final end = _normalizeOdoo(h.dateTo!);

      while (!day.isAfter(end)) {
        if (!day.isBefore(monthStart) && !day.isAfter(monthEnd)) {
          holidayDates.add(day);
        }
        day = day.add(const Duration(days: 1));
      }
    }
  }

  String hoursToHHMM(double hours) {
    final int h = hours.floor();
    final int m = ((hours - h) * 60).round();

    return '${h.toString().padLeft(2, '0')}:${m.toString().padLeft(2, '0')}';
  }

  Future<void> fetchEmployeeByEmployeeId(int employeeId) async {
    isLoading = true;
    notifyListeners();

    try {
      attendanceEmployeeModel =
          await AdministratorAttendanceService.fetchEmployeeByEmployeeId(
            employeeId,
          );

      await fetchWorkingSchedule();
      notifyListeners();

    } catch (e) {
    } finally {
      isLoading = false;
      notifyListeners();
    }
  }

  Future<void> loadMonthlyLeaveCount({
    required int employeeId,
    required DateTime month,
  }) async {
    _monthlyLeaveCount =
        await AdministratorAttendanceService.fetchMonthlyLeaveDays(
          employeeId: employeeId,
          month: month,
        );
    _recalculateAttendance(DateTime.now());
    notifyListeners();
  }

  int _getWorkingDaysInMonth(DateTime month) {
    int workingDays = 0;
    final int totalDays = DateTime(month.year, month.month + 1, 0).day;

    for (int day = 1; day <= totalDays; day++) {
      final date = DateTime(month.year, month.month, day);
      if (date.weekday != DateTime.saturday &&
          date.weekday != DateTime.sunday) {
        workingDays++;
      }
    }

    return workingDays;
  }

  void _recalculateAttendance(DateTime month) {
    final int present = _monthlyAttendanceCount;
    final int workingDays = _getWorkingDaysInMonth(month);

    if (workingDays == 0) {
      _attendancePercentage = 0;
    } else {
      _attendancePercentage = double.parse(
        ((present / workingDays) * 100).toStringAsFixed(2),
      );
    }

    notifyListeners();
  }

  Future<void> fetchWorkingSchedule() async {
    isWorkingScheduleLoading = true;
    notifyListeners();
    try {
      final calendarId = attendanceEmployeeModel?.resourceCalendarId;
      if (calendarId == null) return;
      modelHrWorkingSchedules =
          await AdministratorAttendanceService.fetchWorkingCalendar(
            calendarId: calendarId,
          );
    } catch (e) {
    } finally {
      isWorkingScheduleLoading = false;
      notifyListeners();
    }
  }

  int _odooDayFromDate(DateTime date) {
    /// Dart: Monday = 1 → Odoo: 0
    return date.weekday - 1;
  }

  String _formatHour(double hour) {
    final int h = hour.floor();
    final int m = ((hour - h) * 60).round();
    final DateTime temp = DateTime(2024, 1, 1, h, m);
    return DateFormat('hh:mm a').format(temp);
  }

  String? getCompanyShiftTime() {
    final schedule = modelHrWorkingSchedules;
    if (schedule == null) return null;

    final validLines = schedule.attendanceLines
        .where((e) => (e.durationHours ?? 0) > 0)
        .toList();

    if (validLines.isEmpty) return null;

    final start = validLines
        .map((e) => e.hourFrom)
        .reduce((a, b) => a < b ? a : b);

    final end = validLines.map((e) => e.hourTo).reduce((a, b) => a > b ? a : b);

    return '${_formatHour(start)} - ${_formatHour(end)}';
  }

  void clearOnLogout() {
    isInitialLoaded = false;
    loadedMonths.clear();
    attendanceEmployeeModel = null;
    hasLoadedOnce = false;
    unusualDates.clear();
    leaveDates.clear();
    holidayDates.clear();
    attendanceDates.clear();

    allLeaves.clear();
    employeeModel = null;
    modelHrWorkingSchedules = null;
    modelLeaveUnusualDays = null;
    _monthlyAttendanceCount = 0;
    _monthlyLeaveCount = 0;
    _attendancePercentage = 0;
    isLoading = false;
    isMonthlyLoading = false;
    isWorkingScheduleLoading = false;
    checkOut = null;
    checkInn = null;
    selectedDay = DateTime.now();
    selectedMonth = DateTime.now();
    focusedDay = DateTime.now();
    notifyListeners();
  }
}
