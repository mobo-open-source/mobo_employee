import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:hugeicons/hugeicons.dart';
import 'package:mobo_employees/core/const/all_design.dart';

/// Common search field + filter button, used instead of ad-hoc per-screen
/// search bars so every list view looks and behaves the same.
class MoboSearchBar extends StatefulWidget {
  final TextEditingController controller;
  final String hintText;
  final VoidCallback? onFilterTap;
  final ValueChanged<String>? onChanged;
  final bool readOnly;
  final bool hasActiveFilter;
  final bool showBorder;

  const MoboSearchBar({
    super.key,
    required this.controller,
    this.hintText = 'Search...',
    this.onFilterTap,
    this.onChanged,
    this.readOnly = false,
    this.hasActiveFilter = false,
    this.showBorder = false,
  });

  @override
  State<MoboSearchBar> createState() => _MoboSearchBarState();
}

class _MoboSearchBarState extends State<MoboSearchBar> {
  static final List<BoxShadow> _designShadow = [
    BoxShadow(
      color: Colors.black.withValues(alpha: 0.04),
      offset: const Offset(3, 11),
      blurRadius: 8.5,
      spreadRadius: -3,
    ),
  ];

  static const double _height = 48;
  static const double _radius = 12;

  // How long to wait after the user stops typing before actually searching.
  static const Duration _debounce = Duration(milliseconds: 450);
  Timer? _debounceTimer;

  @override
  void initState() {
    super.initState();
    widget.controller.addListener(_rebuild);
  }

  @override
  void didUpdateWidget(MoboSearchBar oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.controller != widget.controller) {
      oldWidget.controller.removeListener(_rebuild);
      widget.controller.addListener(_rebuild);
    }
  }

  @override
  void dispose() {
    _debounceTimer?.cancel();
    widget.controller.removeListener(_rebuild);
    super.dispose();
  }

  void _rebuild() => setState(() {});

  void _onFieldChanged(String value) {
    _debounceTimer?.cancel();
    _debounceTimer = Timer(_debounce, () => widget.onChanged?.call(value));
  }

  void _clear() {
    _debounceTimer?.cancel();
    widget.controller.clear();
    widget.onChanged?.call('');
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final hasFilter = widget.onFilterTap != null;

    final surface = isDark ? AppColors.elevatedDark : AppColors.surfaceLight;
    final textColor = isDark ? Colors.white : AppColors.textPrimary;
    final hintColor = isDark
        ? Colors.white.withValues(alpha: 0.55)
        : AppColors.textHint;
    final iconColor = isDark
        ? Colors.white.withValues(alpha: 0.70)
        : AppColors.textHint;

    return Row(
      children: [
        Expanded(
          child: _buildSearchField(isDark, surface, textColor, hintColor, iconColor),
        ),
        if (hasFilter) ...[
          const SizedBox(width: 10),
          _buildFilterButton(isDark, surface),
        ],
      ],
    );
  }

  Widget _buildSearchField(
    bool isDark,
    Color surface,
    Color textColor,
    Color hintColor,
    Color iconColor,
  ) {
    return Container(
      height: _height,
      decoration: BoxDecoration(
        color: surface,
        borderRadius: BorderRadius.circular(_radius),
        border: widget.showBorder
            ? Border.all(
                color: isDark
                    ? Colors.white.withValues(alpha: 0.12)
                    : const Color(0xFFE5E7EB),
                width: 1,
              )
            : null,
        boxShadow: isDark ? [] : _designShadow,
      ),
      child: TextField(
        controller: widget.controller,
        readOnly: widget.readOnly,
        onChanged: widget.onChanged == null ? null : _onFieldChanged,
        textInputAction: TextInputAction.search,
        onSubmitted: widget.onChanged == null
            ? null
            : (value) {
                _debounceTimer?.cancel();
                widget.onChanged!(value);
              },
        style: TextStyle(fontSize: 14, color: textColor),
        decoration: InputDecoration(
          isCollapsed: true,
          contentPadding:
              const EdgeInsets.symmetric(horizontal: 12, vertical: 14),
          hintText: widget.hintText,
          hintStyle:
              TextStyle(color: hintColor, fontWeight: FontWeight.w400, fontSize: 14),
          prefixIcon: Padding(
            padding: const EdgeInsets.only(left: 14, right: 8),
            child: HugeIcon(
              icon: HugeIcons.strokeRoundedSearch01,
              size: 20,
              color: iconColor,
            ),
          ),
          prefixIconConstraints: const BoxConstraints(minWidth: 0, minHeight: 0),
          suffixIcon: widget.controller.text.isNotEmpty
              ? IconButton(
                  splashRadius: 18,
                  padding: EdgeInsets.zero,
                  constraints: const BoxConstraints(),
                  icon: HugeIcon(
                    icon: HugeIcons.strokeRoundedCancel01,
                    size: 18,
                    color: iconColor,
                  ),
                  onPressed: _clear,
                )
              : null,
          suffixIconConstraints: const BoxConstraints(minWidth: 40, minHeight: 40),
          border: InputBorder.none,
          enabledBorder: InputBorder.none,
          focusedBorder: InputBorder.none,
          filled: false,
        ),
      ),
    );
  }

  Widget _buildFilterButton(bool isDark, Color surface) {
    final iconColor = isDark ? Colors.white : AppColors.textPrimary;

    return Container(
      width: _height,
      height: _height,
      decoration: BoxDecoration(
        color: surface,
        borderRadius: BorderRadius.circular(_radius),
        border: widget.showBorder
            ? Border.all(
                color: isDark
                    ? Colors.white.withValues(alpha: 0.12)
                    : const Color(0xFFE5E7EB),
                width: 1,
              )
            : null,
        boxShadow: isDark ? [] : _designShadow,
      ),
      child: Material(
        color: Colors.transparent,
        borderRadius: BorderRadius.circular(_radius),
        child: InkWell(
          borderRadius: BorderRadius.circular(_radius),
          onTap: widget.readOnly ? null : widget.onFilterTap,
          child: Center(
            child: SvgPicture.asset(
              'assets/icons/new_filter.svg',
              width: 18,
              height: 18,
              colorFilter: ColorFilter.mode(iconColor, BlendMode.srcIn),
            ),
          ),
        ),
      ),
    );
  }
}
