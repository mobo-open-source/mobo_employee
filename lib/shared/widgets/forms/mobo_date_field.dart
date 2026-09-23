import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:hugeicons/hugeicons.dart';
import 'package:intl/intl.dart';
import 'package:mobo_employees/core/const/all_design.dart';
import 'package:mobo_employees/core/widgets/mobo_date_picker.dart';

/// Labeled date-picker field that taps to open [MoboDatePicker].
class MoboDateField extends StatelessWidget {
  final String label;
  final bool isRequired;
  final DateTime? value;
  final ValueChanged<DateTime?> onChanged;
  final String hintText;
  final bool isDark;
  final bool clearable;

  const MoboDateField({
    super.key,
    required this.label,
    required this.value,
    required this.onChanged,
    this.isDark = false,
    this.isRequired = false,
    this.hintText = 'Select date',
    this.clearable = false,
  });

  Future<void> _pick(BuildContext context) async {
    final picked = await MoboDatePicker.show(
      context: context,
      initialDate: value ?? DateTime.now(),
    );
    if (picked != null) onChanged(picked);
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildLabel(),
        const SizedBox(height: 8),
        _buildDateBox(context),
      ],
    );
  }

  Widget _buildLabel() {
    return Text.rich(
      TextSpan(
        text: label,
        style: GoogleFonts.manrope(
          fontSize: 13,
          fontWeight: FontWeight.w500,
          color: isDark ? Colors.white70 : const Color(0xFF7F7F7F),
        ),
        children: isRequired
            ? [
                TextSpan(
                  text: ' *',
                  style: TextStyle(
                    color: AppColors.error,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ]
            : null,
      ),
    );
  }

  Widget _buildDateBox(BuildContext context) {
    final hasValue = value != null;
    return InkWell(
      onTap: () => _pick(context),
      borderRadius: BorderRadius.circular(12),
      child: Container(
        height: 50,
        padding: const EdgeInsets.symmetric(horizontal: 16),
        decoration: BoxDecoration(
          color: AppColors.inputFill(isDark),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Row(
          children: [
            HugeIcon(
              icon: HugeIcons.strokeRoundedCalendar03,
              size: 20,
              color: isDark ? Colors.grey[400]! : Colors.grey[600]!,
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                hasValue
                    ? DateFormat('MMM dd, yyyy').format(value!)
                    : hintText,
                style: GoogleFonts.manrope(
                  fontSize: 14,
                  fontWeight: FontWeight.w500,
                  color: hasValue
                      ? (isDark ? Colors.white : Colors.black)
                      : (isDark ? Colors.grey[600]! : Colors.grey[400]!),
                  fontStyle:
                      hasValue ? FontStyle.normal : FontStyle.italic,
                ),
              ),
            ),
            if (clearable && hasValue)
              GestureDetector(
                onTap: () => onChanged(null),
                child: HugeIcon(
                  icon: HugeIcons.strokeRoundedCancel01,
                  size: 18,
                  color: isDark ? Colors.grey[500]! : Colors.grey[400]!,
                ),
              )
            else
              HugeIcon(
                icon: HugeIcons.strokeRoundedArrowDown01,
                size: 18,
                color: isDark ? Colors.grey[400]! : Colors.grey[600]!,
              ),
          ],
        ),
      ),
    );
  }
}
