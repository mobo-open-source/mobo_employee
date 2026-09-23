import 'package:flutter/material.dart';
import 'package:flutter_typeahead/flutter_typeahead.dart';
import 'package:google_fonts/google_fonts.dart';

import 'package:mobo_employees/core/const/all_design.dart';

/// Generic single-select search-in-field picker shared by every typeahead
/// dropdown in the app (employee, leave type, etc.). Callers keep full
/// control of how each option (and the selected value's leading
/// avatar/icon) is rendered.
class MoboTypeaheadField<T> extends StatefulWidget {
  final T? selectedItem;
  final ValueChanged<T?> onChanged;
  final Future<List<T>> Function(String pattern) suggestionsCallback;
  final String Function(T) displayText;
  final Widget Function(BuildContext context, T item) itemBuilder;
  final Widget Function(T item)? selectedLeadingBuilder;
  final Widget? unselectedLeadingIcon;
  final bool isDark;
  final String hintText;
  final String emptyText;
  final double popupMaxHeight;
  final bool isLoading;
  final bool Function(T a, T b)? compareFn;

  /// Optional label rendered above the field, matching [MoboFormField]/
  /// [MoboDateField]'s label styling. Omit for callers that render their
  /// own label separately.
  final String? label;
  final bool isRequired;

  const MoboTypeaheadField({
    super.key,
    required this.selectedItem,
    required this.onChanged,
    required this.suggestionsCallback,
    required this.displayText,
    required this.itemBuilder,
    this.isDark = false,
    this.selectedLeadingBuilder,
    this.unselectedLeadingIcon,
    this.hintText = 'Search...',
    this.emptyText = 'No results found',
    this.popupMaxHeight = 260,
    this.isLoading = false,
    this.compareFn,
    this.label,
    this.isRequired = false,
  });

  @override
  State<MoboTypeaheadField<T>> createState() => _MoboTypeaheadFieldState<T>();
}

class _MoboTypeaheadFieldState<T> extends State<MoboTypeaheadField<T>> {
  final _ctrl = TextEditingController();
  final _focusNode = FocusNode();
  final _suggestionsController = SuggestionsController<T>();
  final _popupKey = GlobalKey();
  String _lastValidText = '';

  @override
  void initState() {
    super.initState();
    _syncText(widget.selectedItem);
    _focusNode.addListener(_handleFocusChange);
  }

  @override
  void didUpdateWidget(MoboTypeaheadField<T> oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.selectedItem != oldWidget.selectedItem) {
      _syncText(widget.selectedItem);
    }
  }

  void _handleFocusChange() {
    if (!_focusNode.hasFocus && _ctrl.text != _lastValidText) {
      _ctrl.text = _lastValidText;
    }
  }

  void _syncText(T? item) {
    final text = item != null ? widget.displayText(item) : '';
    _ctrl.text = text;
    _lastValidText = text;
  }

  Future<void> _clearAndReopen() async {
    _ctrl.clear();
    _lastValidText = '';
    widget.onChanged(null);
    _focusNode.requestFocus();
    _suggestionsController.open();
    _suggestionsController.isLoading = true;
    final list = await widget.suggestionsCallback('');
    if (!mounted) return;
    _suggestionsController.suggestions = list;
    _suggestionsController.isLoading = false;
  }

  @override
  void dispose() {
    _focusNode.removeListener(_handleFocusChange);
    _ctrl.dispose();
    _focusNode.dispose();
    _suggestionsController.dispose();
    super.dispose();
  }

  /// Only unfocuses for a tap/drag truly outside the popup, checked against
  /// its own rendered bounds via [_popupKey] — the popup renders in an
  /// `Overlay`, so the field's built-in outside-tap detection alone can
  /// misfire on a scroll gesture started inside the list.
  void _handleTapOutside(PointerDownEvent event) {
    final popupBox =
        _popupKey.currentContext?.findRenderObject() as RenderBox?;
    if (popupBox != null && popupBox.attached) {
      final localPosition = popupBox.globalToLocal(event.position);
      if (popupBox.size.contains(localPosition)) {
        return;
      }
    }
    FocusManager.instance.primaryFocus?.unfocus();
  }

  Future<List<T>> _search(String pattern) async {
    final term = pattern.trim().toLowerCase();
    final selectedText = widget.selectedItem != null
        ? widget.displayText(widget.selectedItem as T).trim().toLowerCase()
        : '';
    /// Tapping a field already filled with the selected item's text should
    /// browse the full list again, not narrow to a self-match.
    final effectivePattern = term == selectedText ? '' : pattern.trim();
    final results = await widget.suggestionsCallback(effectivePattern);
    return _withSelectedFirst(results);
  }

  bool _isSameItem(T a, T b) =>
      widget.compareFn != null ? widget.compareFn!(a, b) : a == b;

  List<T> _withSelectedFirst(List<T> list) {
    final selected = widget.selectedItem;
    if (selected == null) return list;
    final index = list.indexWhere((item) => _isSameItem(item, selected));
    if (index <= 0) return list;
    final reordered = List<T>.of(list);
    reordered.removeAt(index);
    reordered.insert(0, selected);
    return reordered;
  }

  @override
  Widget build(BuildContext context) {
    final field = _buildField(context);
    if (widget.label == null) return field;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text.rich(
          TextSpan(
            text: widget.label,
            style: GoogleFonts.manrope(
              fontSize: 13,
              fontWeight: FontWeight.w500,
              color: widget.isDark ? Colors.white70 : const Color(0xFF7F7F7F),
            ),
            children: widget.isRequired
                ? [
                    TextSpan(
                      text: ' *',
                      style: TextStyle(color: AppColors.error, fontWeight: FontWeight.bold),
                    ),
                  ]
                : null,
          ),
        ),
        const SizedBox(height: 8),
        field,
      ],
    );
  }

  Widget _buildField(BuildContext context) {
    final isDark = widget.isDark;
    final selected = widget.selectedItem != null;

    return TypeAheadField<T>(
      controller: _ctrl,
      focusNode: _focusNode,
      suggestionsController: _suggestionsController,
      autoFlipDirection: true,
      autoFlipMinHeight: 180,
      builder: (ctx, controller, focusNode) => Container(
        decoration: BoxDecoration(
          color: AppColors.inputFill(isDark),
          borderRadius: BorderRadius.circular(12),
        ),
        child: TextField(
          controller: controller,
          focusNode: focusNode,
          readOnly: widget.isLoading,
          enabled: !widget.isLoading,
          onTapOutside: _handleTapOutside,
          style: TextStyle(
            fontSize: 14,
            color: isDark ? Colors.white : Colors.black87,
            fontWeight: selected ? FontWeight.w600 : FontWeight.w400,
          ),
          decoration: InputDecoration(
            hintText: widget.isLoading ? 'Loading...' : widget.hintText,
            hintStyle: TextStyle(
              fontSize: 14,
              color: isDark ? Colors.white54 : Colors.grey[600],
              fontStyle: FontStyle.italic,
            ),
            contentPadding:
                const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
            border: InputBorder.none,
            prefixIcon: widget.isLoading
                ? Padding(
                    padding: const EdgeInsets.all(14),
                    child: SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(
                          strokeWidth: 2, color: AppColors.appColor),
                    ),
                  )
                : (selected && widget.selectedLeadingBuilder != null
                    ? widget.selectedLeadingBuilder!(widget.selectedItem as T)
                    : (widget.unselectedLeadingIcon ??
                        Icon(Icons.search_rounded,
                            size: 17,
                            color: isDark ? Colors.white38 : Colors.black38))),
            suffixIcon: selected
                ? GestureDetector(
                    onTap: _clearAndReopen,
                    child: Icon(Icons.close_rounded,
                        size: 17,
                        color: isDark ? Colors.white38 : Colors.black45),
                  )
                : Icon(Icons.keyboard_arrow_down_rounded,
                    size: 20, color: isDark ? Colors.white38 : Colors.black38),
          ),
        ),
      ),
      suggestionsCallback: _search,
      itemBuilder: (ctx, item) {
        final isSelected = widget.selectedItem != null &&
            _isSameItem(item, widget.selectedItem as T);
        return Container(
          color: isSelected
              ? (isDark
                  ? AppColors.appColor.withValues(alpha: 0.12)
                  : AppColors.appColor.withValues(alpha: 0.07))
              : Colors.transparent,
          child: widget.itemBuilder(ctx, item),
        );
      },
      onSelected: (item) {
        final text = widget.displayText(item);
        _ctrl.text = text;
        _lastValidText = text;
        widget.onChanged(item);
        FocusManager.instance.primaryFocus?.unfocus();
      },
      loadingBuilder: (_) => Padding(
        padding: const EdgeInsets.all(16),
        child: Center(
          child: SizedBox(
            width: 20,
            height: 20,
            child: CircularProgressIndicator(strokeWidth: 2, color: AppColors.appColor),
          ),
        ),
      ),
      emptyBuilder: (_) => Padding(
        padding: const EdgeInsets.all(16),
        child: Text(
          widget.emptyText,
          style: TextStyle(
              fontSize: 13, color: isDark ? Colors.white54 : Colors.grey.shade600),
        ),
      ),
      decorationBuilder: (ctx, child) => Material(
        key: _popupKey,
        type: MaterialType.card,
        elevation: 6,
        borderRadius: BorderRadius.circular(12),
        color: isDark ? AppColors.popupDark : Colors.white,
        child: ConstrainedBox(
          constraints: BoxConstraints(maxHeight: widget.popupMaxHeight),
          child: child,
        ),
      ),
    );
  }
}
