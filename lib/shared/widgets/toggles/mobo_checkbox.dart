import 'package:flutter/material.dart';

import '../../../../core/theme/app_theme.dart';

/// Rounded-square checkbox: a 2px brand-coloured outline that fills in with a
/// check when [value] is true (white fill and black check in dark mode).
///
/// Passing a null [onChanged] disables taps; the box keeps its look so a
/// locked-on option (e.g. the active company) still reads as ticked.
class MoboCheckbox extends StatefulWidget {
  final bool value;
  final ValueChanged<bool>? onChanged;
  final double size;
  final double radius;

  /// Override the disabled-state border/fill colors; left null, disabled
  /// renders exactly like enabled.
  final Color? disabledBorderColor;
  final Color? disabledFillColor;

  const MoboCheckbox({
    super.key,
    required this.value,
    required this.onChanged,
    this.size = 22,
    this.radius = AppRadius.segmentChip,
    this.disabledBorderColor,
    this.disabledFillColor,
  });

  @override
  State<MoboCheckbox> createState() => _MoboCheckboxState();
}

class _MoboCheckboxState extends State<MoboCheckbox> {
  bool _hovering = false;

  @override
  Widget build(BuildContext context) {
    const primary = AppTheme.primaryColor;
    final isDisabled = widget.onChanged == null;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final accent = isDark ? Colors.white : primary;

    return MouseRegion(
      onEnter: (_) => setState(() => _hovering = true),
      onExit: (_) => setState(() => _hovering = false),
      child: GestureDetector(
        onTap: isDisabled ? null : () => widget.onChanged!(!widget.value),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 150),
          curve: Curves.easeInOut,
          width: widget.size,
          height: widget.size,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(widget.radius),
            border: Border.all(
              color: isDisabled
                  ? (widget.disabledBorderColor ?? accent)
                  : accent,
              width: 2,
            ),
            color: widget.value
                ? (isDisabled ? (widget.disabledFillColor ?? accent) : accent)
                : (_hovering
                      ? accent.withValues(alpha: 0.10)
                      : Colors.transparent),
          ),
          child: widget.value
              ? Icon(
                  Icons.check_rounded,
                  size: widget.size * 0.75,
                  color: isDark ? Colors.black : Colors.white,
                )
              : null,
        ),
      ),
    );
  }
}
