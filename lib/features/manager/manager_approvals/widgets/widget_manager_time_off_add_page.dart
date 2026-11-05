import 'package:flutter/material.dart';
import 'package:mobo_employees/features/manager/manager_approvals/models/model_time_off_add_employees.dart';
import 'package:mobo_employees/features/manager/manager_approvals/models/model_time_off_add_time_off_type.dart';
import 'package:mobo_employees/features/manager/manager_approvals/providers/manager_approvals_provider.dart';
import 'package:provider/provider.dart';
import '../../../../shared/widgets/forms/mobo_date_field.dart';
import '../../../../shared/widgets/forms/mobo_file_upload_box.dart';
import '../../../../shared/widgets/forms/mobo_form_field.dart';
import '../../../../shared/widgets/pickers/employee_typeahead_field.dart';
import '../../../../shared/widgets/sheets/form_sheet_shell.dart';
import '../../../../shared/widgets/sheets/sheet_submit_button.dart';
import '../../../../shared/widgets/pickers/mobo_typeahead_field.dart';
import '../../../../widgets/snackbar_widgets.dart';

class WidgetManagerTimeOffAddPage extends StatefulWidget {
  const WidgetManagerTimeOffAddPage({super.key});

  @override
  State<WidgetManagerTimeOffAddPage> createState() =>
      _WidgetManagerTimeOffAddPageState();
}

class _WidgetManagerTimeOffAddPageState
    extends State<WidgetManagerTimeOffAddPage> {
  @override
  void initState() {
    super.initState();
    final provider = context.read<ManagerApprovalsProvider>();
    if (provider.employees.isEmpty) {
      provider.fetchEmployees();
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Consumer<ManagerApprovalsProvider>(
      builder: (context, provider, _) {
        return FormSheetShell(
          title: "Apply for Leave",
          onClose: () {
            provider.clearForm();
            Navigator.pop(context);
          },

          footer: SheetSubmitButton(
            label: "Submit Request",
            loadingLabel: "Submitting Request...",
            isLoading: provider.isSaveMyTimeOffLoading,
            enabled: provider.isSubmitEnabled,
            isDark: isDark,
            onPressed: () async {
              // The toast is a dialog route, so the sheet closes first and the
              // toast shows on the screen underneath it.
              final navigator = Navigator.of(context);
              final error = await provider.saveLeave();

              if (error == null) {
                if (navigator.mounted) {
                  navigator.pop();
                  CustomSnackbar.showSuccess(
                    navigator.context,
                    "Successfully Requested",
                  );
                }
              } else {
                if (context.mounted) {
                  CustomSnackbar.showError(context, error);
                }
              }
            },
          ),
          children: [
            EmployeeTypeaheadField<Employee>(
              label: "Employee",
              isRequired: true,
              isDark: isDark,
              isLoading:
                  provider.isEmployeesLoading && provider.employees.isEmpty,
              employees: provider.employees,
              selectedEmployee: provider.employees
                  .where((e) => e.id == provider.selectedEmployeeId)
                  .firstOrNull,
              displayName: (emp) => emp.name,
              avatarBytes: (emp) => emp.imageBytes,
              compareFn: (a, b) => a.id == b.id,
              hintText: "Search employee",
              onChanged: (emp) {
                if (emp == null) {
                  provider.selectedEmployeeId = null;
                  provider.employeeController.clear();
                  provider.departmentController.clear();
                  // Time off types are fetched per employee, so the
                  // chosen one goes with the employee.
                  provider.leaveTypeController.clear();
                  provider.notify();
                  return;
                }
                provider.employeeController.text = emp.name;
                provider.departmentController.text = emp.departmentName ?? '';
                provider.selectedEmployeeId = emp.id;
                provider.fetchLeaveTypes();
                provider.notify();
              },
            ),
            const SizedBox(height: 10),
            MoboFormField(
              label: "Department",
              readOnly: true,
              isDark: isDark,
              controller: provider.departmentController,
              hintText: "Auto-filled from employee",
            ),
            const SizedBox(height: 10),
            MoboTypeaheadField<ModelTimeOffAddTimeOffType>(
              label: "Time Off Type",
              isRequired: true,
              isDark: isDark,
              selectedItem: provider.leaveTypes
                  .where((lt) => lt.name == provider.leaveTypeController.text)
                  .firstOrNull,
              hintText: "Select Leave Type",
              emptyText: "No leave types found",
              displayText: (lt) => lt.name,
              compareFn: (a, b) => a.id == b.id,
              suggestionsCallback: (query) async {
                if (provider.leaveTypes.isEmpty) {
                  await provider.fetchLeaveTypes();
                }
                return provider.leaveTypes
                    .where(
                      (lt) =>
                          lt.name.toLowerCase().contains(query.toLowerCase()),
                    )
                    .toList();
              },
              itemBuilder: (context, lt) => ListTile(
                dense: true,
                leading: CircleAvatar(
                  backgroundColor: Colors.blue.shade100,
                  child: Text(
                    lt.name.isNotEmpty ? lt.name[0].toUpperCase() : '?',
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      color: isDark ? Colors.black87 : null,
                    ),
                  ),
                ),
                title: Text(
                  lt.name,
                  style: TextStyle(color: isDark ? Colors.white : null),
                ),
              ),
              onChanged: (lt) {
                provider.leaveTypeController.text = lt?.name ?? '';
                provider.notify();
              },
            ),
            const SizedBox(height: 10),
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: MoboDateField(
                    label: "From Date",
                    isRequired: true,
                    isDark: isDark,
                    value: provider.fromDate,
                    onChanged: (date) {
                      if (date != null) provider.setFromDate(date);
                    },
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: MoboDateField(
                    label: "To Date",
                    isRequired: true,
                    isDark: isDark,
                    value: provider.toDate,
                    errorText: provider.dateRangeError,
                    onChanged: (date) {
                      if (date != null) provider.setToDate(date);
                    },
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),
            MoboFormField(
              label: "Description",
              isDark: isDark,
              controller: provider.descriptionController,
              hintText: "Enter description here...",
              maxLines: 4,
            ),
            const SizedBox(height: 10),
            MoboFileUploadBox(
              isDark: isDark,
              fileName: provider.attachedFileName,
              onPick: provider.pickFile,
              onRemove: provider.removeFile,
            ),
          ],
        );
      },
    );
  }
}
