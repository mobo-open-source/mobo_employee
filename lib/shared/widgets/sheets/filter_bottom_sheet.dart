import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:mobo_employees/core/const/all_design.dart';
import 'package:mobo_employees/core/theme/app_theme.dart';

import '../../../widgets/snackbar_widgets.dart';
import '../filters/date_range_filter_fields.dart';

/// A titled group of filter chips within [FilterBottomSheet]'s Filter tab.
/// Pass a single section with no [title] for a flat (ungrouped) chip list.
class FilterSection<F> {
  final String? title;
  final List<(F value, String label)> items;
  const FilterSection(this.items, {this.title});
}

/// A single option within [FilterBottomSheet]'s Group By tab.
/// Include a "None" entry as the first item if the caller supports it —
/// the sheet renders whatever list it's given, in order.
class GroupByOption<G> {
  final G value;
  final String label;
  final String subtitle;
  const GroupByOption(this.value, this.label, this.subtitle);
}

/// Shared "Filter & Group By" bottom sheet shell — handle, header, Filter/
/// Group By tabs, active-filter chips, group-by list, and a Clear All/Apply
/// footer.
///
/// The sheet only tracks selection state (a `Set` of F for filters, a
/// `Set` of G for group-by); callers own their own filter enums, provider
/// wiring, and what "apply"/"clear" actually does.
class FilterBottomSheet<F, G> extends StatefulWidget {
  final List<FilterSection<F>> filterSections;
  final Set<F> initialSelected;
  final String filterTabLabel;

  /// If false, selecting a filter chip replaces the current selection
  /// instead of toggling it on top of others (radio-like via chips) — use
  /// for filters where only one value makes sense at a time.
  final bool allowMultipleFilters;

  final List<GroupByOption<G>> groupByOptions;
  final Set<G> initialGroupBy;

  /// Whether [groupByOptions] starts with a "None" entry. The grey rule on
  /// the Group By tab then sits under that entry alone (as in the events
  /// app); with no "None" entry — the options are all real fields to group
  /// on — it sits between the "Group by" heading and the first option, and
  /// the options themselves are not separated.
  final bool groupByHasNone;

  /// If false (default), the Group By tab behaves like a radio group — one
  /// value at a time, rendered as [RadioListTile]s. If true, it behaves like
  /// a checkbox group so multiple dimensions can be combined/nested
  /// (rendered as [CheckboxListTile]s) — used where a caller supports
  /// combined/nested grouping (e.g. Month + Employee).
  final bool allowMultipleGroupBy;

  /// Optional date-range section shown at the bottom of the Filter tab
  /// (e.g. "Attendance Date" with Start Date / End Date pickers). Omit
  /// [dateRangeTitle] (leave it null) for callers that don't need one.
  final String? dateRangeTitle;
  final DateTime? initialStartDate;
  final DateTime? initialEndDate;

  final Future<void> Function(
    Set<F> selectedFilters,
    Set<G> groupBy,
    DateTime? startDate,
    DateTime? endDate,
  )
  onApply;
  final Future<void> Function() onClearAll;

  const FilterBottomSheet({
    super.key,
    required this.filterSections,
    required this.initialSelected,
    required this.groupByOptions,
    required this.initialGroupBy,
    required this.onApply,
    required this.onClearAll,
    this.allowMultipleFilters = true,
    this.allowMultipleGroupBy = false,
    this.groupByHasNone = true,
    this.filterTabLabel = 'Filter',
    this.dateRangeTitle,
    this.initialStartDate,
    this.initialEndDate,
  });

  @override
  State<FilterBottomSheet<F, G>> createState() =>
      _FilterBottomSheetState<F, G>();
}

class _FilterBottomSheetState<F, G> extends State<FilterBottomSheet<F, G>>
    with TickerProviderStateMixin {
  /// Side inset shared by everything in the sheet — the Filter / Group By
  /// switch's margin — so the title, chips, date fields, Group By rows and
  /// buttons all start and end on the same line.
  static const double _inset = 16;

  late final TabController _tabController;
  late Set<F> _selected;
  late Set<G> _groupBy;
  DateTime? _startDate;
  DateTime? _endDate;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _tabController.addListener(() => setState(() {}));
    _selected = {...widget.initialSelected};
    _groupBy = {...widget.initialGroupBy};
    _startDate = widget.initialStartDate;
    _endDate = widget.initialEndDate;
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  void _toggle(F value) {
    setState(() {
      if (widget.allowMultipleFilters) {
        _selected.contains(value)
            ? _selected.remove(value)
            : _selected.add(value);
      } else {
        _selected = {value};
      }
    });
  }

  void _toggleGroupBy(G value) {
    setState(() {
      if (widget.allowMultipleGroupBy) {
        _groupBy.contains(value) ? _groupBy.remove(value) : _groupBy.add(value);
      } else {
        _groupBy = {value};
      }
    });
  }

  void _apply() {
    if (!DateRangeFilterFields.isValid(_startDate, _endDate)) {
      // The toast is a dialog route, so it shows above the sheet.
      CustomSnackbar.showError(context, DateRangeFilterFields.rangeError);
      return;
    }
    Navigator.pop(context);
    Future.microtask(
      () => widget.onApply(_selected, _groupBy, _startDate, _endDate),
    );
  }

  void _clearAll() {
    Navigator.pop(context);
    Future.microtask(() => widget.onClearAll());
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Container(
      height: MediaQuery.of(context).size.height * 0.8,
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1E1E1E) : Colors.grey[50],
        borderRadius: const BorderRadius.vertical(top: Radius.circular(16)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildHandle(isDark),
          _buildHeader(isDark),
          _buildTabBar(isDark),
          Expanded(
            child: TabBarView(
              controller: _tabController,
              children: [_buildFilterTab(isDark), _buildGroupByTab(isDark)],
            ),
          ),
          _buildBottomActions(isDark),
        ],
      ),
    );
  }

  Widget _buildHandle(bool isDark) {
    return Container(
      padding: const EdgeInsets.only(top: 12, bottom: 8),
      child: Center(
        child: Container(
          width: 40,
          height: 4,
          decoration: BoxDecoration(
            color: isDark ? Colors.grey[700] : Colors.grey[300],
            borderRadius: BorderRadius.circular(2),
          ),
        ),
      ),
    );
  }

  Widget _buildHeader(bool isDark) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: _inset, vertical: 16),
      child: Row(
        children: [
          Expanded(
            child: Text(
              'Filter & Group By',
              style: TextStyle(
                color: isDark ? Colors.white : Colors.black87,
                fontSize: 18,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
          IconButton(
            onPressed: () => Navigator.of(context).pop(),
            icon: Icon(
              Icons.close,
              color: isDark ? Colors.white70 : Colors.black54,
            ),
            splashRadius: 20,
          ),
        ],
      ),
    );
  }

  Widget _buildTabBar(bool isDark) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: _inset),
      decoration: BoxDecoration(
        color: isDark ? Colors.grey[900] : Colors.grey[100],
        borderRadius: BorderRadius.circular(12),
      ),
      child: TabBar(
        controller: _tabController,
        indicator: BoxDecoration(
          color: AppColors.appColor,
          borderRadius: BorderRadius.circular(10),
        ),
        indicatorPadding: const EdgeInsets.all(4),
        indicatorSize: TabBarIndicatorSize.tab,
        dividerColor: Colors.transparent,
        labelColor: Colors.white,
        unselectedLabelColor: isDark ? Colors.grey[500] : Colors.grey[600],
        // TabBar applies these as-is, without the theme's font.
        labelStyle: GoogleFonts.manrope(
          fontWeight: FontWeight.w600,
          fontSize: 14,
        ),
        unselectedLabelStyle: GoogleFonts.manrope(
          fontWeight: FontWeight.w500,
          fontSize: 14,
        ),
        splashFactory: NoSplash.splashFactory,
        overlayColor: WidgetStateProperty.all(Colors.transparent),
        tabs: [
          Tab(height: 48, text: widget.filterTabLabel),
          const Tab(height: 48, text: 'Group By'),
        ],
        onTap: (_) => setState(() {}),
      ),
    );
  }

  Widget _buildFilterTab(bool isDark) {
    final allItems = widget.filterSections.expand((s) => s.items).toList();
    final active = allItems.where((e) => _selected.contains(e.$1)).toList();
    return SingleChildScrollView(
      physics: const BouncingScrollPhysics(),
      padding: const EdgeInsets.fromLTRB(_inset, 10, _inset, 20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (active.isNotEmpty) ...[
            Text(
              'Active Filters',
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w600,
                color: isDark ? Colors.white : AppColors.appColor,
              ),
            ),
            const SizedBox(height: 12),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: active
                  .map(
                    (e) => _buildActiveChip(e.$2, isDark, () => _toggle(e.$1)),
                  )
                  .toList(),
            ),
            const SizedBox(height: 4),
          ],
          if (widget.filterSections.expand((s) => s.items).isEmpty)
            Padding(
              padding: const EdgeInsets.only(top: 24),
              child: Text(
                'No filters available',
                style: TextStyle(
                  fontSize: 13,
                  color: isDark ? Colors.grey[500] : Colors.grey[600],
                ),
              ),
            ),
          ...widget.filterSections.map(
            (section) => _buildSection(section, isDark),
          ),
          if (widget.dateRangeTitle != null) _buildDateRangeSection(isDark),
        ],
      ),
    );
  }

  Widget _buildDateRangeSection(bool isDark) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(0, 24, 0, 12),
          child: Text(
            widget.dateRangeTitle!,
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w600,
              color: isDark ? Colors.grey[400] : Colors.grey[600],
            ),
          ),
        ),
        DateRangeFilterFields(
          startDate: _startDate,
          endDate: _endDate,
          startPlaceholder: 'Start Date',
          endPlaceholder: 'End Date',
          onStartChanged: (date) => setState(() => _startDate = date),
          onEndChanged: (date) => setState(() => _endDate = date),
        ),
      ],
    );
  }

  Widget _buildActiveChip(String label, bool isDark, VoidCallback onRemove) {
    // As in the events app, the × takes the label's colour (brand in light
    // mode) rather than a neutral grey.
    final chipColor = isDark ? Colors.white : AppColors.appColor;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: AppColors.appColor.withOpacity(0.1),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.appColor.withOpacity(0.2)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            label,
            style: TextStyle(
              fontSize: 12,
              color: chipColor,
              fontWeight: FontWeight.w500,
            ),
          ),
          const SizedBox(width: 6),
          GestureDetector(
            onTap: onRemove,
            child: Icon(Icons.close, size: 14, color: chipColor),
          ),
        ],
      ),
    );
  }

  Widget _buildSection(FilterSection<F> section, bool isDark) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (section.title != null)
          Padding(
            padding: const EdgeInsets.fromLTRB(0, 24, 0, 12),
            child: Text(
              section.title!,
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w600,
                color: isDark ? Colors.grey[400] : Colors.grey[600],
              ),
            ),
          ),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: section.items.map((e) {
            final selected = _selected.contains(e.$1);
            // An option at rest: in dark mode a neutral grey box with white text
            // and a grey outline, as the events app's filter chips (the pale
            // brand wash that suits the light sheet glows pink on a dark one).
            return ChoiceChip(
              label: Text(
                e.$2,
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: selected || isDark
                      ? FontWeight.w600
                      : FontWeight.w400,
                  color: selected || isDark ? Colors.white : Colors.black87,
                ),
              ),
              selected: selected,
              selectedColor: AppColors.appColor,
              backgroundColor: isDark
                  ? AppTheme.darkOptionFill
                  : AppTheme.primaryWash,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(8),
                side: BorderSide(
                  color: selected
                      ? AppColors.appColor
                      : (isDark
                            ? AppTheme.darkOptionBorder
                            : Colors.grey[300]!),
                ),
              ),
              onSelected: (_) => _toggle(e.$1),
              showCheckmark: false,
            );
          }).toList(),
        ),
      ],
    );
  }

  Widget _buildGroupByTab(bool isDark) {
    final rule = Divider(color: isDark ? Colors.grey[800] : Colors.grey[200]);
    return SingleChildScrollView(
      physics: const BouncingScrollPhysics(),
      padding: const EdgeInsets.symmetric(horizontal: _inset, vertical: 20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Group by',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w600,
              color: isDark ? Colors.white : Colors.grey[800],
            ),
          ),
          // The rule's own 8px either side makes up the rest of the gap.
          SizedBox(height: widget.groupByHasNone ? 16 : 8),
          if (!widget.groupByHasNone) rule,
          for (var i = 0; i < widget.groupByOptions.length; i++) ...[
            _buildGroupByTile(widget.groupByOptions[i], isDark),
            if (widget.groupByHasNone && i == 0) ...[
              const SizedBox(height: 8),
              rule,
            ],
          ],
        ],
      ),
    );
  }

  Widget _buildGroupByTile(GroupByOption<G> option, bool isDark) {
    final titleStyle = TextStyle(
      color: isDark ? Colors.white : Colors.black87,
      fontWeight: FontWeight.w500,
    );
    final subtitleStyle = TextStyle(
      color: isDark ? Colors.grey[500] : Colors.grey[600],
      fontSize: 12,
    );

    if (widget.allowMultipleGroupBy) {
      return CheckboxListTile(
        title: Text(option.label, style: titleStyle),
        subtitle: Text(option.subtitle, style: subtitleStyle),
        value: _groupBy.contains(option.value),
        onChanged: (_) => _toggleGroupBy(option.value),
        controlAffinity: ListTileControlAffinity.leading,
        contentPadding: EdgeInsets.zero,
      );
    }

    return RadioListTile<G>(
      title: Text(option.label, style: titleStyle),
      subtitle: Text(option.subtitle, style: subtitleStyle),
      value: option.value,
      groupValue: _groupBy.isEmpty ? null : _groupBy.first,
      onChanged: (v) => _toggleGroupBy(v as G),
      activeColor: AppColors.appColor,
      contentPadding: EdgeInsets.zero,
    );
  }

  Widget _buildBottomActions(bool isDark) {
    return Container(
      padding: EdgeInsets.only(
        left: _inset,
        right: _inset,
        top: 20,
        bottom: 20 + MediaQuery.of(context).padding.bottom,
      ),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1E1E1E) : Colors.grey[50],
        border: Border(
          top: BorderSide(
            color: isDark ? Colors.grey[800]! : Colors.grey[200]!,
            width: 1,
          ),
        ),
      ),
      child: Row(
        children: [
          Expanded(
            child: SizedBox(
              height: 48,
              child: OutlinedButton(
                onPressed: _clearAll,
                style: OutlinedButton.styleFrom(
                  foregroundColor: AppColors.appColor,
                  side: BorderSide(color: AppColors.appColor, width: 1.5),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                child: const Text(
                  'Clear All',
                  style: TextStyle(fontWeight: FontWeight.w500, fontSize: 16),
                ),
              ),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: SizedBox(
              height: 48,
              child: ElevatedButton(
                onPressed: _apply,
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.appColor,
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  elevation: 0,
                  shadowColor: Colors.transparent,
                ),
                child: const Text(
                  'Apply',
                  style: TextStyle(fontWeight: FontWeight.w600, fontSize: 16),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
