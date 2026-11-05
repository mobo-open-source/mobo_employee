import 'package:flutter/material.dart';
import 'package:hugeicons/hugeicons.dart';
import 'package:intl/intl.dart';

import '../../../core/theme/app_theme.dart';
import '../../../core/utils/date_range_validator.dart';
import '../../../core/widgets/mobo_date_picker.dart';

/// Start / end date pickers for a filter sheet's date-range section.
///
/// The range is validated inline: a start date after the end date outlines
/// both fields in red and explains why beneath them. Sheets also check
/// [isValid] before applying, so a reversed range is never sent as a filter.
class DateRangeFilterFields extends StatelessWidget {
  final DateTime? startDate;
  final DateTime? endDate;
  final ValueChanged<DateTime?> onStartChanged;
  final ValueChanged<DateTime?> onEndChanged;

  /// Shown in an empty field.
  final String startPlaceholder;
  final String endPlaceholder;

  const DateRangeFilterFields({
    super.key,
    required this.startDate,
    required this.endDate,
    required this.onStartChanged,
    required this.onEndChanged,
    this.startPlaceholder = 'Select start date',
    this.endPlaceholder = 'Select end date',
  });

  static const String rangeError = 'Start date cannot be after end date';

  /// Whether [start]..[end] is a usable range — either end may be open.
  static bool isValid(DateTime? start, DateTime? end) =>
      !DateRangeValidator.isStartAfterEnd(start, end);

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final hasError = !isValid(startDate, endDate);
    final now = DateTime.now();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildField(
          context,
          isDark: isDark,
          hasError: hasError,
          value: startDate,
          label: 'From',
          placeholder: startPlaceholder,
          onTap: () async {
            final date = await MoboDatePicker.show(
              context: context,
              initialDate: startDate ?? now,
              firstDate: DateTime(now.year - 5),
              lastDate: DateTime(now.year + 5),
              helpText: 'Select Start Date',
            );
            if (date != null) onStartChanged(date);
          },
          onClear: () => onStartChanged(null),
        ),
        const SizedBox(height: 8),
        _buildField(
          context,
          isDark: isDark,
          hasError: hasError,
          value: endDate,
          label: 'To',
          placeholder: endPlaceholder,
          onTap: () async {
            final date = await MoboDatePicker.show(
              context: context,
              initialDate: endDate ?? now,
              firstDate: DateTime(now.year - 5),
              lastDate: DateTime(now.year + 5),
              helpText: 'Select End Date',
            );
            if (date != null) onEndChanged(date);
          },
          onClear: () => onEndChanged(null),
        ),
        AnimatedSwitcher(
          duration: const Duration(milliseconds: 200),
          child: hasError
              ? const Padding(
                  key: ValueKey('range-error'),
                  padding: EdgeInsets.only(top: 4, left: 4),
                  child: Text(
                    rangeError,
                    style: TextStyle(color: StatusColors.red, fontSize: 12),
                  ),
                )
              : const SizedBox.shrink(),
        ),
      ],
    );
  }

  Widget _buildField(
    BuildContext context, {
    required bool isDark,
    required bool hasError,
    required DateTime? value,
    required String label,
    required String placeholder,
    required VoidCallback onTap,
    required VoidCallback onClear,
  }) {
    final iconColor = isDark ? Colors.grey[400]! : Colors.grey[600]!;
    final borderRadius = BorderRadius.circular(AppRadius.control);

    // A fixed height, so the field is the same size empty or filled — an
    // IconButton inside the row would pull it up to its own 48px tap target.
    // The same light Mobo wash as the option chips above it.
    return Material(
      color: AppTheme.primaryWash,
      shape: RoundedRectangleBorder(
        borderRadius: borderRadius,
        side: BorderSide(
          color: hasError
              ? StatusColors.red
              : (isDark ? Colors.grey[700]! : Colors.grey[300]!),
        ),
      ),
      child: InkWell(
        onTap: onTap,
        borderRadius: borderRadius,
        child: SizedBox(
          height: 44,
          child: Padding(
            padding: const EdgeInsets.only(left: 14, right: 6),
            child: Row(
              children: [
                HugeIcon(
                  icon: HugeIcons.strokeRoundedCalendar03,
                  size: 16,
                  color: iconColor,
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    value != null
                        ? '$label: ${DateFormat('MMM dd, yyyy').format(value)}'
                        : placeholder,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: value != null
                          ? FontWeight.w500
                          : FontWeight.w400,
                      color: value != null
                          ? (isDark ? Colors.white : Colors.grey[800])
                          : iconColor,
                    ),
                  ),
                ),
                if (value != null)
                  InkResponse(
                    onTap: onClear,
                    radius: 18,
                    child: SizedBox.square(
                      dimension: 32,
                      child: Icon(Icons.clear, size: 16, color: iconColor),
                    ),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
