import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:hugeicons/hugeicons.dart';
import 'package:loading_animation_widget/loading_animation_widget.dart';
import 'package:mobo_employees/core/const/all_design.dart';
import 'package:mobo_employees/core/exceptions/odoo_error_mapper.dart';
import 'package:mobo_employees/core/services/user_access_service.dart';
import 'package:mobo_employees/core/theme/app_theme.dart';
import 'package:mobo_employees/core/utils/date_range_validator.dart';
import 'package:mobo_employees/features/manager/manager_approvals/models/model_time_off_add_employees.dart';
import 'package:mobo_employees/features/manager/manager_approvals/services/manager_calendar_service.dart';
import 'package:mobo_employees/features/manager/manager_attendance/service/manager_attendance_data_service.dart';

import '../../../../shared/widgets/forms/mobo_date_time_field.dart';
import '../../../../shared/widgets/pickers/employee_typeahead_field.dart';
import '../../../../widgets/snackbar_widgets.dart';

/// Bottom sheet mirroring Odoo's Attendances > New form: an employee, a
/// check-in and an optional check-out (left empty while still checked in).
class AttendanceCreateSheet extends StatefulWidget {
  /// The employees Odoo lets this user create attendances for (see
  /// [UserAccessService.attendanceCreateDomain]).
  final List<dynamic> employeeDomain;

  const AttendanceCreateSheet({super.key, required this.employeeDomain});

  /// Opens the sheet. Resolves to `true` once an attendance was created.
  static Future<bool> show(
    BuildContext context, {
    required List<dynamic> employeeDomain,
  }) async {
    final created = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      isDismissible: false,
      enableDrag: false,
      backgroundColor: Colors.transparent,
      builder: (_) => AttendanceCreateSheet(employeeDomain: employeeDomain),
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
      employees = await ManagerCalendarService.fetchManagerAddTimeOffEmployees(
        domain: widget.employeeDomain,
      );
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
      await ManagerAttendanceDataService.createAttendance(
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

    /// The back button must not close the sheet mid-save either: the request
    /// would still create the attendance, unseen by the list.
    return PopScope(
      canPop: !_isSaving,
      child: Padding(
        padding: EdgeInsets.only(
          bottom: MediaQuery.of(context).viewInsets.bottom,
        ),
        child: SingleChildScrollView(
          child: Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: isDark ? AppTheme.darkSurface : Colors.white,
              borderRadius: const BorderRadius.vertical(
                top: Radius.circular(20),
              ),
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      "New Attendance",
                      style: GoogleFonts.manrope(
                        fontSize: 18,
                        fontWeight: FontWeight.w500,
                        color: isDark ? Colors.white : AppColors.color000000,
                      ),
                    ),
                    InkWell(
                      onTap: _isSaving ? null : _close,
                      child: Container(
                        padding: const EdgeInsets.all(6),
                        decoration: BoxDecoration(
                          color: isDark
                              ? AppColors.inputFillDark
                              : AppColors.colorF3F3F5,
                          shape: BoxShape.circle,
                        ),
                        child: HugeIcon(
                          icon: HugeIcons.strokeRoundedCancel01,
                          color: isDark ? Colors.white : AppColors.color000000,
                          size: 18,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 20),
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
                const SizedBox(height: 40),
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton(
                        onPressed: _isSaving ? null : _close,
                        style: OutlinedButton.styleFrom(
                          backgroundColor: isDark
                              ? Colors.transparent
                              : AppColors.whiteColor,
                          side: BorderSide(color: AppColors.appColor),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                          padding: const EdgeInsets.symmetric(vertical: 14),
                        ),
                        child: Text(
                          "Cancel",
                          style: GoogleFonts.manrope(
                            fontSize: 14,
                            fontWeight: FontWeight.w500,
                            color: AppColors.appColor,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: ElevatedButton(
                        onPressed: _isSubmitEnabled ? _submit : null,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppColors.colorC03355,
                          disabledBackgroundColor: isDark
                              ? Colors.grey[700]
                              : AppColors.colorD1D5DC,
                          elevation: 0,
                          shadowColor: Colors.transparent,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                          padding: const EdgeInsets.symmetric(vertical: 14),
                        ),
                        child: _isSaving
                            ? LoadingAnimationWidget.staggeredDotsWave(
                                color: AppColors.whiteColor,
                                size: 20,
                              )
                            : Text(
                                "Save",
                                style: GoogleFonts.manrope(
                                  fontSize: 14,
                                  fontWeight: FontWeight.w600,
                                  color: AppColors.colorFFFFFF,
                                ),
                              ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 30),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
