import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:hugeicons/hugeicons.dart';
import 'package:loading_animation_widget/loading_animation_widget.dart';
import 'package:mobo_employees/core/const/all_design.dart';
import 'package:mobo_employees/features/manager/manager_approvals/models/model_time_off_add_employees.dart';
import 'package:mobo_employees/features/manager/manager_approvals/models/model_time_off_add_time_off_type.dart';
import 'package:mobo_employees/features/manager/manager_approvals/providers/manager_approvals_provider.dart';
import 'package:provider/provider.dart';
import '../../../../shared/widgets/forms/mobo_date_field.dart';
import '../../../../shared/widgets/forms/mobo_form_field.dart';
import '../../../../shared/widgets/pickers/employee_typeahead_field.dart';
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
    return Consumer<ManagerApprovalsProvider>(
      builder: (context, provider, _) {
        return Padding(
          padding: EdgeInsets.only(
            bottom: MediaQuery.of(context).viewInsets.bottom,
          ),
          child: SingleChildScrollView(
            keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
            child: Container(
              padding: const EdgeInsets.all(20),
              decoration: const BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  /// ---------------- HEADER ----------------
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        "Apply for Leave",
                        style: GoogleFonts.manrope(
                          fontSize: 18,
                          fontWeight: FontWeight.w500,
                          color: AppColors.color000000,
                        ),
                      ),
                      InkWell(
                        onTap: () {
                          provider.clearForm();
                          Navigator.pop(context);
                        },
                        child: Container(
                          padding: const EdgeInsets.all(6),
                          decoration: BoxDecoration(
                            color: AppColors.colorF3F3F5,
                            shape: BoxShape.circle,
                          ),
                          child: HugeIcon(
                            icon: HugeIcons.strokeRoundedCancel01,
                            color: AppColors.color000000,
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
                        provider.notifyListeners();
                        return;
                      }
                      provider.employeeController.text = emp.name;
                      provider.departmentController.text =
                          emp.departmentName ?? '';
                      provider.selectedEmployeeId = emp.id;
                      provider.fetchLeaveTypes();
                      provider.notifyListeners();
                    },
                  ),
                  const SizedBox(height: 10),
                  MoboFormField(
                    label: "Department",
                    readOnly: true,
                    controller: provider.departmentController,
                    hintText: "Auto-filled from employee",
                  ),
                  const SizedBox(height: 10),
                  MoboTypeaheadField<ModelTimeOffAddTimeOffType>(
                    label: "Time Off Type",
                    isRequired: true,
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
                            (lt) => lt.name.toLowerCase().contains(
                              query.toLowerCase(),
                            ),
                          )
                          .toList();
                    },
                    itemBuilder: (context, lt) => ListTile(
                      dense: true,
                      leading: CircleAvatar(
                        backgroundColor: Colors.blue.shade100,
                        child: Text(
                          lt.name.isNotEmpty ? lt.name[0].toUpperCase() : '?',
                          style: const TextStyle(fontWeight: FontWeight.bold),
                        ),
                      ),
                      title: Text(lt.name),
                    ),
                    onChanged: (lt) {
                      provider.leaveTypeController.text = lt?.name ?? '';
                      provider.notify();
                    },
                  ),
                  const SizedBox(height: 10),
                  Row(
                    children: [
                      Expanded(
                        child: MoboDateField(
                          label: "From Date",
                          isRequired: true,
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
                          value: provider.toDate,
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
                    controller: provider.descriptionController,
                    hintText: "Enter description here...",
                    maxLines: 4,
                  ),
                  const SizedBox(height: 10),
                  Row(
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              "File",
                              style: GoogleFonts.manrope(
                                fontSize: 13,
                                fontWeight: FontWeight.w400,
                                color: AppColors.color6A7282,
                              ),
                            ),

                            if (provider.attachedFileName != null)
                              Column(
                                children: [
                                  const SizedBox(height: 10),
                                  Container(
                                    margin: const EdgeInsets.only(bottom: 8),
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 12,
                                      vertical: 10,
                                    ),
                                    decoration: BoxDecoration(
                                      color: AppColors.colorF3F3F5,
                                      borderRadius: BorderRadius.circular(10),
                                    ),
                                    child: Row(
                                      children: [
                                        const Icon(
                                          Icons.insert_drive_file,
                                          size: 18,
                                        ),
                                        const SizedBox(width: 8),
                                        Expanded(
                                          child: Text(
                                            provider.attachedFileName!,
                                            overflow: TextOverflow.ellipsis,
                                            style: const TextStyle(
                                              fontSize: 13,
                                            ),
                                          ),
                                        ),
                                        GestureDetector(
                                          onTap: provider.removeFile,
                                          child: const Icon(
                                            Icons.close,
                                            size: 18,
                                            color: Colors.red,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                ],
                              ),

                            const SizedBox(height: 5),

                            /// 🔥 PICK FILE BUTTON
                            Container(
                              height: 45,
                              decoration: BoxDecoration(
                                color: AppColors.colorEEEEEE,
                                borderRadius: BorderRadius.circular(10),
                              ),
                              child: InkWell(
                                borderRadius: BorderRadius.circular(10),
                                onTap: provider.pickFile,
                                child: Padding(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 12,
                                  ),
                                  child: Row(
                                    mainAxisAlignment: MainAxisAlignment.center,
                                    children: [
                                      HugeIcon(
                                        icon:
                                            HugeIcons.strokeRoundedAttachment01,
                                        size: 18,
                                        color: AppColors.color000000,
                                      ),
                                      const SizedBox(width: 8),
                                      Text(
                                        "Attach File",
                                        style: GoogleFonts.manrope(
                                          fontSize: 14,
                                          fontWeight: FontWeight.w500,
                                          color: AppColors.color000000,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 50),
                  Row(
                    children: [
                      Expanded(
                        child: OutlinedButton(
                          onPressed: () {
                            provider.clearForm();
                            Navigator.pop(context);
                          },
                          style: OutlinedButton.styleFrom(
                            backgroundColor: AppColors.whiteColor,
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
                          onPressed:
                              provider.isSubmitEnabled &&
                                  !provider.isSaveMyTimeOffLoading
                              ? () async {


                                  final error = await provider.saveLeave();

                                  if (error == null) {
                                    if (context.mounted) {
                                      Navigator.pop(context);
                                      CustomSnackbar.showSuccess(
                                        context,
                                        "Successfully Requested",
                                      );
                                    }
                                  } else {
                                    if (context.mounted) {
                                      CustomSnackbar.showError(context, error);
                                    }
                                  }
                                }
                              : null,
                          style: ElevatedButton.styleFrom(
                            backgroundColor: provider.isSubmitEnabled
                                ? AppColors.colorC03355
                                : AppColors.colorD1D5DC,
                            elevation: 0,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                            padding: const EdgeInsets.symmetric(vertical: 14),
                          ),
                          child: provider.isSaveMyTimeOffLoading
                              ? Row(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    const SizedBox(width: 8),
                                    Flexible(
                                      child: Text(
                                        "Submitting Request...",
                                        overflow: TextOverflow.ellipsis,
                                        style: GoogleFonts.manrope(
                                          fontSize: 14,
                                          fontWeight: FontWeight.w600,
                                          color: AppColors.colorFFFFFF,
                                        ),
                                      ),
                                    ),
                                    LoadingAnimationWidget.staggeredDotsWave(
                                      color: AppColors.whiteColor,
                                      size: 20,
                                    ),
                                  ],
                                )
                              : Text(
                                  "Submit Request",
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
        );
      },
    );
  }

}
