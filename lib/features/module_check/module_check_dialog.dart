import 'package:flutter/material.dart';

class ModuleCheckDialog extends StatelessWidget {
  final List<String> moduleName;
  const ModuleCheckDialog({super.key, required this.moduleName});

  @override
  Widget build(BuildContext context) {
    final readableNames = {
      'hr': 'Employee',
      'hr_attendance': 'Attendance',
      'hr_payroll': 'Payroll',
      'hr_holidays': 'Time Off',
    };

    final readableModules = moduleName
        .map((m) => readableNames[m] ?? m)
        .toList();

    return Dialog(
      backgroundColor: Colors.white,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      insetPadding: const EdgeInsets.symmetric(horizontal: 24),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: const [
                Icon(Icons.error_outline, color: Colors.red, size: 26),
                SizedBox(width: 10),
                Text(
                  "Module Missing",
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                ),
              ],
            ),

            const SizedBox(height: 14),

            Text(
              'The required "${readableModules.join(', ')}" module'
              '${readableModules.length > 1 ? 's are' : ' is'} not installed. '
              'Please contact your administrator to enable '
              '${readableModules.length > 1 ? 'them.' : 'it.'}',
              style: const TextStyle(fontSize: 14, color: Colors.black87),
            ),

            const SizedBox(height: 24),

            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFFC03355),
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14),
                  ),
                ),
                onPressed: () {
                  Navigator.of(context, rootNavigator: true).pop();
                },
                child: const Text(
                  "Back to Login",
                  style: TextStyle(
                    fontSize: 16,
                    color: Colors.white,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ),
            const SizedBox(height: 14),
          ],
        ),
      ),
    );
  }
}
