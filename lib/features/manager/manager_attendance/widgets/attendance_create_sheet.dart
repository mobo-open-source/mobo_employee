import 'package:flutter/material.dart';
import 'package:mobo_employees/core/exceptions/odoo_error_mapper.dart';
import 'package:mobo_employees/core/services/user_access_service.dart';
import 'package:mobo_employees/core/utils/date_range_validator.dart';
import 'package:mobo_employees/features/manager/manager_approvals/models/model_time_off_add_employees.dart';
import 'package:mobo_employees/features/manager/manager_approvals/services/manager_calendar_service.dart';
import 'package:mobo_employees/features/manager/manager_attendance/service/manager_attendance_data_service.dart';

import '../../../../shared/widgets/forms/mobo_date_time_field.dart';
import '../../../../shared/widgets/pickers/employee_typeahead_field.dart';
import '../../../../shared/widgets/sheets/form_sheet_shell.dart';
import '../../../../shared/widgets/sheets/sheet_submit_button.dart';
import '../../../../widgets/snackbar_widgets.dart';

/// Popup, in the middle of the screen, mirroring Odoo's Attendances > New form:
/// an employee, a check-in and an optional check-out (left empty while still
/// checked in). While it saves, the loading animation covers the form.
class AttendanceCreateSheet extends StatefulWidget {
  /// The employees Odoo lets this user create attendances for (see
  /// [UserAccessService.attendanceCreateDomain]).
  final List<dynamic> employeeDomain;

  /// Where the employees come from and where the attendance is saved: the
  /// server, unless a test stands in for it.
  final Future<List<Employee>> Function(List<dynamic> domain) loadEmployees;
  final Future<void> Function({
    required int employeeId,
    required DateTime checkIn,
    DateTime? checkOut,
  })
  saveAttendance;

  const AttendanceCreateSheet({
    super.key,
    required this.employeeDomain,
    this.loadEmployees = _loadFromServer,
    this.saveAttendance = _saveToServer,
  });

  static Future<List<Employee>> _loadFromServer(List<dynamic> domain) =>
      ManagerCalendarService.fetchManagerAddTimeOffEmployees(domain: domain);

  static Future<void> _saveToServer({
    required int employeeId,
    required DateTime checkIn,
    DateTime? checkOut,
  }) => ManagerAttendanceDataService.createAttendance(
    employeeId: employeeId,
    checkIn: checkIn,
    checkOut: checkOut,
  );

  /// Opens the popup. Resolves to `true` once an attendance was created.
  static Future<bool> show(
    BuildContext context, {
    required List<dynamic> employeeDomain,
    Future<List<Employee>> Function(List<dynamic> domain) loadEmployees =
        _loadFromServer,
    Future<void> Function({
          required int employeeId,
          required DateTime checkIn,
          DateTime? checkOut,
        })
        saveAttendance =
        _saveToServer,
  }) async {
    final created = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (_) => AttendanceCreateSheet(
        employeeDomain: employeeDomain,
        loadEmployees: loadEmployees,
        saveAttendance: saveAttendance,
      ),
    );
    return created == true;
  }

  @override
  State<AttendanceCreateSheet> createState() => _AttendanceCreateSheetState();
}

class _AttendanceCreateSheetState extends State<AttendanceCreateSheet> {
  List<Employee> _employees = [];
  bool _isLoadingEmployees = true;
  bool _isSaving = false;

  Employee? _employee;
  DateTime? _checkIn = _nowToMinute();
  DateTime? _checkOut;

  static DateTime _nowToMinute() {
    final now = DateTime.now();
    return DateTime(now.year, now.month, now.day, now.hour, now.minute);
  }

  @override
  void initState() {
    super.initState();
    _loadEmployees();
  }

  Future<void> _loadEmployees() async {
    List<Employee> employees = [];
    try {
      employees = await widget.loadEmployees(widget.employeeDomain);
    } catch (e) {
      /// Server unreachable: stop the picker's spinner and say why it's
      /// empty instead of leaving it loading.
      if (mounted) {
        CustomSnackbar.showError(
          context,
          OdooErrorMapper.serverMessage(
            e,
            fallback: 'Could not load employees. Please try again.',
          ),
        );
      }
    }
    if (!mounted) return;
    setState(() {
      _employees = employees;
      _isLoadingEmployees = false;
    });
  }

  String? get _checkOutError {
    final checkIn = _checkIn;
    final checkOut = _checkOut;
    if (checkIn == null || checkOut == null) return null;
    return checkOut.isBefore(checkIn)
        ? DateRangeValidator.attendanceMessage
        : null;
  }

  bool get _isSubmitEnabled =>
      _employee != null && _checkIn != null && !_isSaving;

  Future<void> _submit() async {
    final error = _checkOutError;
    if (error != null) {
      CustomSnackbar.showError(context, error);
      return;
    }

    setState(() => _isSaving = true);
    try {
      await widget.saveAttendance(
        employeeId: _employee!.id,
        checkIn: _checkIn!,
        checkOut: _checkOut,
      );

      /// Stays "saving" while the sheet animates out, so Save can't create a
      /// second attendance.
      if (mounted) _close(created: true);
    } catch (e) {
      if (mounted) {
        setState(() => _isSaving = false);
        CustomSnackbar.showError(
          context,
          OdooErrorMapper.serverMessage(
            e,
            fallback: 'Could not create the attendance. Please try again.',
          ),
        );
      }
    }
  }

  /// Closes this sheet and only this sheet. A bare `Navigator.pop` pops
  /// whatever route is on top, so with a dialog above the sheet, or the
  /// sheet already closing, it closed the attendance page instead — leaving
  /// a black screen.
  void _close({bool created = false}) {
    final route = ModalRoute.of(context);
    if (route == null || !route.isActive) return;
    if (route.isCurrent) {
      Navigator.pop(context, created);
    } else {
      Navigator.of(context).removeRoute(route, created);
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    /// The back button must not close the popup mid-save either: the request
    /// would still create the attendance, unseen by the list.
    return PopScope(
      canPop: !_isSaving,
      child: FormSheetShell(
        centered: true,
        title: "New Attendance",
        onClose: _isSaving ? null : _close,
        busyMessage: _isSaving ? "Saving attendance..." : null,
        footer: SheetSubmitButton(
          label: "Save",
          isLoading: _isSaving,
          enabled: _isSubmitEnabled,
          isDark: isDark,
          onPressed: _submit,
        ),
        children: [
          EmployeeTypeaheadField<Employee>(
            label: "Employee",
            isRequired: true,
            isDark: isDark,
            isLoading: _isLoadingEmployees,
            employees: _employees,
            selectedEmployee: _employee,
            displayName: (emp) => emp.name,
            avatarBytes: (emp) => emp.imageBytes,
            compareFn: (a, b) => a.id == b.id,
            hintText: "Search employee",
            onChanged: (emp) => setState(() => _employee = emp),
          ),
          const SizedBox(height: 10),
          MoboDateTimeField(
            label: "Check In",
            isRequired: true,
            isDark: isDark,
            value: _checkIn,
            onChanged: (value) {
              if (value != null) setState(() => _checkIn = value);
            },
          ),
          const SizedBox(height: 10),
          MoboDateTimeField(
            label: "Check Out",
            isDark: isDark,
            value: _checkOut,
            hintText: "Still checked in",
            clearable: true,
            errorText: _checkOutError,
            onChanged: (value) => setState(() => _checkOut = value),
          ),
        ],
      ),
    );
  }
}
