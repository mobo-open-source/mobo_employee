import 'package:flutter/material.dart';
import '../../../../shared/widgets/forms/mobo_date_field.dart';
import '../../../../shared/widgets/forms/mobo_file_upload_box.dart';
import '../../../../shared/widgets/forms/mobo_form_field.dart';
import '../../../../shared/widgets/pickers/mobo_typeahead_field.dart';
import '../../../../shared/widgets/sheets/form_sheet_shell.dart';
import '../../../../shared/widgets/sheets/sheet_submit_button.dart';
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
        return FormSheetShell(
          title: "Apply for Leave",
          onClose: () => Navigator.pop(context),

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
                  CustomSnackbar.showError(
                    context,
                    error, // show the actual backend error
                  );
                }
              }
            },
          ),
          children: [
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
