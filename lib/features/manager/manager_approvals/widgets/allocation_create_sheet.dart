import 'package:flutter/material.dart';
import 'package:mobo_employees/core/exceptions/odoo_error_mapper.dart';
import 'package:mobo_employees/core/utils/date_range_validator.dart';
import 'package:mobo_employees/features/manager/manager_approvals/models/model_time_off_add_employees.dart';
import 'package:mobo_employees/features/manager/manager_approvals/models/model_time_off_add_time_off_type.dart';
import 'package:mobo_employees/features/manager/manager_approvals/services/manager_calendar_service.dart';

import '../../../../shared/widgets/forms/mobo_date_field.dart';
import '../../../../shared/widgets/forms/mobo_form_field.dart';
import '../../../../shared/widgets/pickers/employee_typeahead_field.dart';
import '../../../../shared/widgets/pickers/mobo_typeahead_field.dart';
import '../../../../shared/widgets/sheets/form_sheet_shell.dart';
import '../../../../shared/widgets/sheets/sheet_submit_button.dart';
import '../../../../widgets/snackbar_widgets.dart';

/// Bottom sheet mirroring Odoo's Time Off > Allocations > New form for a
/// Time Off Officer: employee, time off type, duration in days and the
/// validity period (end date optional, as in Odoo).
class AllocationCreateSheet extends StatefulWidget {
  const AllocationCreateSheet({super.key});

  /// Opens the sheet. Resolves to `true` once an allocation was created.
  static Future<bool> show(BuildContext context) async {
    final created = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      isDismissible: false,
      enableDrag: false,
      backgroundColor: Colors.transparent,
      builder: (_) => const AllocationCreateSheet(),
    );
    return created == true;
  }

  @override
  State<AllocationCreateSheet> createState() => _AllocationCreateSheetState();
}

class _AllocationCreateSheetState extends State<AllocationCreateSheet> {
  List<Employee> _employees = [];
  List<ModelTimeOffAddTimeOffType> _leaveTypes = [];
  bool _isLoadingEmployees = true;
  bool _isLoadingTypes = true;
  bool _isSaving = false;

  Employee? _employee;
  ModelTimeOffAddTimeOffType? _leaveType;

  /// Odoo defaults a new allocation to 1 day, valid from today.
  final _daysController = TextEditingController(text: '1');
  final _descriptionController = TextEditingController();
  DateTime? _dateFrom = DateTime.now();
  DateTime? _dateTo;

  @override
  void initState() {
    super.initState();
    _daysController.addListener(() => setState(() {}));
    ManagerCalendarService.fetchManagerAddTimeOffEmployees().then((list) {
      if (mounted) {
        setState(() {
          _employees = list;
          _isLoadingEmployees = false;
        });
      }
    });
    ManagerCalendarService.fetchAllocatableLeaveTypes().then((list) {
      if (mounted) {
        setState(() {
          _leaveTypes = list;
          _isLoadingTypes = false;
        });
      }
    });
  }

  @override
  void dispose() {
    _daysController.dispose();
    _descriptionController.dispose();
    super.dispose();
  }

  double? get _days {
    final value = double.tryParse(_daysController.text.trim());
    return value != null && value > 0 ? value : null;
  }

  String? get _dateToError =>
      DateRangeValidator.isStartAfterEnd(_dateFrom, _dateTo)
      ? DateRangeValidator.allocationMessage
      : null;

  bool get _isSubmitEnabled =>
      _employee != null &&
      _leaveType != null &&
      _days != null &&
      _dateFrom != null &&
      !_isSaving;

  Future<void> _submit() async {
    final error = _dateToError;
    if (error != null) {
      CustomSnackbar.showError(context, error);
      return;
    }

    setState(() => _isSaving = true);
    try {
      await ManagerCalendarService.createAllocation(
        employeeId: _employee!.id,
        leaveTypeId: _leaveType!.id,
        numberOfDays: _days!,
        dateFrom: _dateFrom!,
        dateTo: _dateTo,
        description: _descriptionController.text,
      );
      if (mounted) Navigator.pop(context, true);
    } catch (e) {
      if (mounted) {
        CustomSnackbar.showError(
          context,
          OdooErrorMapper.serverMessage(
            e,
            fallback: 'Could not create the allocation. Please try again.',
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return FormSheetShell(
      title: "New Allocation",
      onClose: _isSaving ? null : () => Navigator.pop(context),

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
        MoboTypeaheadField<ModelTimeOffAddTimeOffType>(
          label: "Time Off Type",
          isRequired: true,
          isDark: isDark,
          isLoading: _isLoadingTypes,
          selectedItem: _leaveType,
          hintText: "Select Time Off Type",
          emptyText: "No time off types require an allocation",
          displayText: (type) => type.name,
          compareFn: (a, b) => a.id == b.id,
          suggestionsCallback: (query) async => _leaveTypes
              .where(
                (type) => type.name.toLowerCase().contains(query.toLowerCase()),
              )
              .toList(),
          itemBuilder: (context, type) => ListTile(
            dense: true,
            title: Text(
              type.name,
              style: TextStyle(color: isDark ? Colors.white : null),
            ),
          ),
          onChanged: (type) => setState(() => _leaveType = type),
        ),
        const SizedBox(height: 10),
        MoboFormField(
          label: "Duration (days)",
          isRequired: true,
          isDark: isDark,
          controller: _daysController,
          hintText: "e.g. 5",
          keyboardType: const TextInputType.numberWithOptions(decimal: true),
        ),
        const SizedBox(height: 10),
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: MoboDateField(
                label: "Start Date",
                isRequired: true,
                isDark: isDark,
                value: _dateFrom,
                onChanged: (date) {
                  if (date != null) setState(() => _dateFrom = date);
                },
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: MoboDateField(
                label: "End Date",
                isDark: isDark,
                value: _dateTo,
                hintText: "No limit",
                clearable: true,
                errorText: _dateToError,
                onChanged: (date) => setState(() => _dateTo = date),
              ),
            ),
          ],
        ),
        const SizedBox(height: 10),
        MoboFormField(
          label: "Description",
          isDark: isDark,
          controller: _descriptionController,
          hintText: "Enter description here...",
          maxLines: 3,
        ),
      ],
    );
  }
}
