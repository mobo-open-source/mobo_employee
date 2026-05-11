import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:hugeicons/hugeicons.dart';
import 'package:loading_animation_widget/loading_animation_widget.dart';
import 'package:mobo_employees/core/const/all_design.dart';
import 'package:mobo_employees/features/employee/leave/widget/widget_common_text_form_field.dart';
import 'package:mobo_employees/features/employee/leave/widget/widget_common_type_a_head.dart';
import 'package:mobo_employees/features/manager/manager_approvals/models/model_time_off_add_employees.dart';
import 'package:mobo_employees/features/manager/manager_approvals/models/model_time_off_add_time_off_type.dart';
import 'package:mobo_employees/features/manager/manager_approvals/providers/manager_approvals_provider.dart';
import 'package:provider/provider.dart';
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
                  WidgetCommonTypeAHead<Employee>(
                    label: "Employee",
                    controller: provider.employeeController,
                    isDarkTheme: false,
                    hideOnEmpty: false,
                    suggestionsCallback: (query) async {
                      if (provider.employees.isEmpty) {
                        await provider.fetchEmployees();
                      }
                      return provider.employees
                          .where(
                            (emp) => emp.name.toLowerCase().contains(
                              query.toLowerCase(),
                            ),
                          )
                          .toList();
                    },
                    suggestionItemBuilder: (context, emp) {
                      return ListTile(
                        leading: CircleAvatar(
                          backgroundColor: Colors.grey.shade200,
                          child: emp.imageBytes != null
                              ? ClipOval(
                                  child: Image.memory(
                                    emp.imageBytes!,
                                    fit: BoxFit.cover,
                                    width: 40,
                                    height: 40,
                                    errorBuilder: (context, error, stackTrace) {
                                      return _buildInitial(emp.name);
                                    },
                                  ),
                                )
                              : _buildInitial(emp.name),
                        ),
                        title: Text(emp.name),
                        );
                    },
                    onSelected: (emp) {
                      provider.employeeController.text = emp.name;
                      provider.departmentController.text =
                          emp.departmentName ?? '';
                      provider.selectedEmployeeId = emp.id;
                      provider.fetchLeaveTypes();

                      provider.notifyListeners();
                    },
                    fieldBuilder: (context, controller, focusNode) {
                      return TextField(
                        controller: controller,
                        focusNode: focusNode,
                        decoration: InputDecoration(
                          hintText: "Search employee",
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),

                          enabledBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                            borderSide: const BorderSide(
                              color: Colors.transparent,
                            ),
                          ),

                          focusedBorder: const OutlineInputBorder(
                            borderRadius: BorderRadius.only(
                              topLeft: Radius.circular(12),
                              topRight: Radius.circular(12),
                            ),
                          ),

                          filled: true,
                          fillColor: AppColors.colorF3F3F5,
                        ),
                      );
                    },
                  ),
                  const SizedBox(height: 10),
                  Text(
                    "Department",
                    style: GoogleFonts.manrope(
                      fontSize: 13,
                      fontWeight: FontWeight.w400,
                      color: AppColors.color6A7282,
                    ),
                  ),
                  const SizedBox(height: 10),
                  WidgetCommonTextFormField(
                    readOnly: true,
                    controller: provider.departmentController,
                  ),
                  const SizedBox(height: 10),
                  WidgetCommonTypeAHead<ModelTimeOffAddTimeOffType>(
                    label: "Time Off Type",
                    controller: provider.leaveTypeController,
                    isDarkTheme: false,
                    hideOnEmpty: false,

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

                    suggestionItemBuilder: (context, lt) {
                      return ListTile(
                        leading: CircleAvatar(
                          backgroundColor: Colors.blue.shade100,
                          child: Text(
                            lt.name.isNotEmpty ? lt.name[0].toUpperCase() : '?',
                            style: const TextStyle(fontWeight: FontWeight.bold),
                          ),
                        ),
                        title: Text(lt.name),
                      );
                    },

                    onSelected: (lt) {
                      provider.leaveTypeController.text = lt.name;
                      provider.notify();
                    },

                    fieldBuilder: (context, controller, focusNode) {
                      return TextField(
                        controller: controller,
                        focusNode: focusNode,
                        decoration: InputDecoration(
                          hintText: "Select Leave Type",

                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),

                          enabledBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                            borderSide: const BorderSide(
                              color: Colors.transparent,
                            ),
                          ),

                          focusedBorder: const OutlineInputBorder(
                            borderRadius: BorderRadius.only(
                              topLeft: Radius.circular(12),
                              topRight: Radius.circular(12),
                            ),
                          ),

                          /// Optional fill (recommended UI)
                          filled: true,
                          fillColor: AppColors.colorF3F3F5,
                        ),
                      );
                    },
                  ),
                  const SizedBox(height: 10),
                  Row(
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              "From Date",
                              style: GoogleFonts.manrope(
                                fontSize: 13,
                                fontWeight: FontWeight.w400,
                                color: AppColors.color6A7282,
                              ),
                            ),
                            const SizedBox(height: 5),
                            WidgetCommonTextFormField(
                              readOnly: true,
                              controller: provider.fromDateController,
                              onTap: () {
                                provider.chooseDate(
                                  context,
                                  provider.fromDateController,
                                );
                                provider.notify();
                              },
                              prefixIcon: Padding(
                                padding: const EdgeInsets.all(12),
                                child: HugeIcon(
                                  icon: HugeIcons.strokeRoundedCalendar03,
                                  size: 18,
                                  color: AppColors.color6A7282,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              "To Date",
                              style: GoogleFonts.manrope(
                                fontSize: 13,
                                fontWeight: FontWeight.w400,
                                color: AppColors.color6A7282,
                              ),
                            ),
                            const SizedBox(height: 5),
                            WidgetCommonTextFormField(
                              readOnly: true,
                              controller: provider.toDateController,
                              onTap: () {
                                provider.chooseDate(
                                  context,
                                  provider.toDateController,
                                );
                                provider.notify();
                              },
                              prefixIcon: Padding(
                                padding: const EdgeInsets.all(12),
                                child: HugeIcon(
                                  icon: HugeIcons.strokeRoundedCalendar03,
                                  size: 18,
                                  color: AppColors.color6A7282,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 10),
                  Row(
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              "Description",
                              style: GoogleFonts.manrope(
                                fontSize: 13,
                                fontWeight: FontWeight.w400,
                                color: AppColors.color6A7282,
                              ),
                            ),
                            const SizedBox(height: 5),
                            WidgetCommonTextFormField(
                              controller: provider.descriptionController,
                            ),
                          ],
                        ),
                      ),
                    ],
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

  Widget _buildInitial(String name) {
    final letter = name.isNotEmpty ? name.trim()[0].toUpperCase() : '?';

    return Center(
      child: Text(
        letter,
        style: const TextStyle(
          fontWeight: FontWeight.bold,
          fontSize: 16,
          color: Colors.black,
        ),
      ),
    );
  }
}
