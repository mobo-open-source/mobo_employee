import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:hugeicons/hugeicons.dart';
import 'package:loading_animation_widget/loading_animation_widget.dart';
import 'package:mobo_employees/core/const/all_design.dart';
import 'package:mobo_employees/core/theme/app_theme.dart';
import '../../../../shared/widgets/forms/mobo_date_field.dart';
import '../../../../shared/widgets/forms/mobo_form_field.dart';
import '../../../../shared/widgets/pickers/mobo_typeahead_field.dart';
import '../../../../widgets/snackbar_widgets.dart';
import 'package:provider/provider.dart';
import '../model/model_time_off_type.dart';
import '../provider/leave_page_provider.dart';
import '../service/leave_service.dart';

class MyTimeOffAdd extends StatefulWidget {
  const MyTimeOffAdd({super.key});

  @override
  State<MyTimeOffAdd> createState() => _MyTimeOffAddState();
}

class _MyTimeOffAddState extends State<MyTimeOffAdd> {
  @override
  void initState() {
    super.initState();
    Future.microtask(() {
      context.read<LeavePageProvider>().loadTimeOffTypes();
    });
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Consumer<LeavePageProvider>(
      builder: (context, provider, _) {
        return Padding(
          padding: EdgeInsets.only(
            bottom: MediaQuery.of(context).viewInsets.bottom,
          ),
          child: SingleChildScrollView(
            keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
            child: Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: isDark ? AppTheme.darkSurface : Colors.white,
                borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // ---------------- HEADER ----------------
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        "Apply for Leave",
                        style: GoogleFonts.manrope(
                          fontSize: 18,
                          fontWeight: FontWeight.w500,
                          color: isDark ? Colors.white : AppColors.color000000,
                        ),
                      ),
                      InkWell(
                        onTap: () => Navigator.pop(context),
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
                  MoboTypeaheadField<ModelTimeOffType>(
                    label: "Leave Type",
                    isRequired: true,
                    selectedItem: provider.modelTimeOffType,
                    isDark: isDark,
                    hintText: "Select Leave Type",
                    emptyText: "No leave types found",
                    displayText: (item) => item.displayName,
                    compareFn: (a, b) => a.id == b.id,
                    suggestionsCallback: (pattern) =>
                        LeaveService.fetchTimeOffTypes(text: pattern),
                    itemBuilder: (context, item) => ListTile(
                      dense: true,
                      title: Text(
                        item.displayName,
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w500,
                          color: isDark ? Colors.white : null,
                        ),
                      ),
                    ),
                    onChanged: (item) {
                      provider.modelTimeOffType = item;
                      provider.leaveTypeController.text = item?.displayName ?? '';
                      provider.notifyListener();
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
                                color: isDark
                                    ? Colors.white70
                                    : AppColors.color6A7282,
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
                                      color: isDark
                                          ? AppColors.inputFillDark
                                          : AppColors.colorF3F3F5,
                                      borderRadius: BorderRadius.circular(10),
                                    ),
                                    child: Row(
                                      children: [
                                        Icon(
                                          Icons.insert_drive_file,
                                          size: 18,
                                          color: isDark ? Colors.white : null,
                                        ),
                                        const SizedBox(width: 8),
                                        Expanded(
                                          child: Text(
                                            provider.attachedFileName!,
                                            overflow: TextOverflow.ellipsis,
                                            style: TextStyle(
                                              fontSize: 13,
                                              color: isDark ? Colors.white : null,
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
                            Container(
                              height: 45,
                              decoration: BoxDecoration(
                                color: isDark
                                    ? AppColors.inputFillDark
                                    : AppColors.colorEEEEEE,
                                borderRadius: BorderRadius.circular(10),
                              ),
                              child: InkWell(
                                borderRadius: BorderRadius.circular(10),
                                onTap: () {
                                  provider.pickFile();
                                },
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
                                        color: isDark
                                            ? Colors.white
                                            : AppColors.color000000,
                                      ),
                                      const SizedBox(width: 8),
                                      Text(
                                        "Attach File",
                                        style: GoogleFonts.manrope(
                                          fontSize: 14,
                                          fontWeight: FontWeight.w500,
                                          color: isDark
                                              ? Colors.white
                                              : AppColors.color000000,
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
                            Navigator.pop(context);
                          },
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
                          onPressed:
                              provider.isSubmitEnabled &&
                                  !provider.isSaveMyTimeOffLoading
                              ? () async {
                                  // await provider.saveLeave(context: context);
                                  // or

                                  /// Before adding error message snackbar showing

                                  // final success = await provider.saveLeave();
                                  //
                                  // if (success) {
                                  //   if (context.mounted) {
                                  //     Navigator.pop(context);
                                  //     CustomSnackbar.showSuccess(
                                  //       context,
                                  //       "Successfully Requested",
                                  //     );
                                  //   }
                                  // } else {
                                  //   if (context.mounted) {
                                  //     CustomSnackbar.showError(
                                  //       context,
                                  //       "Failed to submit leave request",
                                  //     );
                                  //   }
                                  // }

                                  /// After Adding error message showing as catch error
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
                                      CustomSnackbar.showError(
                                        context,
                                        error, // ✅ show actual backend error
                                      );
                                    }
                                  }
                                }
                              : null,
                          style: ElevatedButton.styleFrom(
                            backgroundColor: provider.isSubmitEnabled
                                ? AppColors.colorC03355
                                : (isDark
                                    ? Colors.grey[700]!
                                    : AppColors.colorD1D5DC),
                            elevation: 0,
                            shadowColor: Colors.transparent,
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
                                          color: Colors.white,
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
                                    color: Colors.white,
                                  ),
                                ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}
