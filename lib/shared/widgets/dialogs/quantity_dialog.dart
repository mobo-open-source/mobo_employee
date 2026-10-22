import 'package:flutter/material.dart';
import 'common_dialog.dart';

/// Reusable quantity input dialog
class QuantityDialog {
  static Future<double?> show(
    BuildContext context, {
    String title = 'Enter Quantity',
    double initialValue = 1.0,
  }) {
    final controller = TextEditingController(text: initialValue.toString());

    return showDialog<double>(
      context: context,
      builder: (ctx) => CommonDialog(
        title: title,
        body: TextField(
          controller: controller,
          keyboardType: const TextInputType.numberWithOptions(decimal: true),
          autofocus: true,
          decoration: const InputDecoration(
            labelText: 'Quantity',
            border: OutlineInputBorder(),
          ),
        ),
        secondaryLabel: 'Cancel',
        onSecondary: () => Navigator.pop(ctx),
        primaryLabel: 'Confirm',
        onPrimary: () {
          final value = double.tryParse(controller.text);
          Navigator.pop(ctx, value);
        },
      ),
    );
  }
}
