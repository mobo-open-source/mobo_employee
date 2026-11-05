import 'package:flutter/material.dart';
import 'package:lottie/lottie.dart';
import 'package:mobo_employees/core/const/all_design.dart';
import 'package:mobo_employees/core/theme/app_theme.dart';

/// The empty state of a filterable list — ghost animation, message and, when a
/// search, filter or group-by is what emptied the list, a "Clear All Filters"
/// button. Laid out as the events app's `NoEventsEmptyState`: a 220px
/// animation, a bold 18px title straight under it, a grey subtitle and the
/// button, all centred horizontally and sitting 120px from the top of the list.
///
/// Meant to be a child of a scrolling list (which gives it unbounded height):
/// the top gap, not vertical centring, is what positions it.
class NoResultsEmptyState extends StatelessWidget {
  /// The title when nothing narrows the list (e.g. "No attendance data").
  final String emptyTitle;

  /// A search, filter or group-by emptied the list: shows the "No results
  /// found" wording and the way out.
  final bool showClearFilters;
  final VoidCallback? onClearFilters;

  const NoResultsEmptyState({
    super.key,
    required this.emptyTitle,
    this.showClearFilters = false,
    this.onClearFilters,
  });

  /// A phone in landscape is only ~300–400dp tall, so the animation shrinks
  /// and the top gap goes, leaving room for the message and the button.
  static const double _shortScreenHeight = 500;

  @override
  Widget build(BuildContext context) {
    final short = MediaQuery.sizeOf(context).height < _shortScreenHeight;
    final illustration = short ? 130.0 : 220.0;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Padding(
      padding: EdgeInsets.only(top: short ? 0 : 120),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          SizedBox(
            height: illustration,
            child: Lottie.asset(
              'assets/lotties/empty ghost.json',
              width: illustration,
            ),
          ),
          Text(
            showClearFilters ? 'No results found' : emptyTitle,
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: isDark ? Colors.white : AppColors.textPrimary,
            ),
          ),
          if (showClearFilters) ...[
            const SizedBox(height: 8),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24),
              child: Text(
                'Try adjusting your filters or group by',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 14,
                  color: isDark ? Colors.white60 : Colors.black54,
                ),
              ),
            ),
            SizedBox(height: short ? 12 : 20),
            ClearAllFiltersButton(onPressed: onClearFilters),
          ],
        ],
      ),
    );
  }
}

/// The action of a list's "No results found" state: clears the filters, the
/// search and the group-by together. Outlined in the brand colour (border and
/// text), 48px tall, radius 12.
class ClearAllFiltersButton extends StatelessWidget {
  final VoidCallback? onPressed;

  const ClearAllFiltersButton({super.key, required this.onPressed});

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 48,
      child: OutlinedButton(
        onPressed: onPressed,
        style: OutlinedButton.styleFrom(
          foregroundColor: AppTheme.primaryColor,
          side: const BorderSide(color: AppTheme.primaryColor, width: 1.5),
          padding: const EdgeInsets.symmetric(horizontal: 24),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(AppRadius.defaultRadius),
          ),
        ),
        child: const Text(
          'Clear All Filters',
          style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
        ),
      ),
    );
  }
}
