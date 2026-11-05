import 'package:flutter/material.dart';
import 'package:hugeicons/hugeicons.dart';
import '../pagination/pagination_controls.dart';

/// Filter-badge + pagination row shown below a list screen's search bar.
class FilterStatusRow extends StatelessWidget {
  final int filterCount;
  final String? groupByLabel;
  final bool isDark;
  final String paginationText;
  final bool canPrev;
  final bool canNext;
  final VoidCallback onPrev;
  final VoidCallback onNext;
  final bool showPagination;

  const FilterStatusRow({
    super.key,
    required this.filterCount,
    this.groupByLabel,
    required this.isDark,
    required this.paginationText,
    required this.canPrev,
    required this.canNext,
    required this.onPrev,
    required this.onNext,
    required this.showPagination,
  });

  @override
  Widget build(BuildContext context) {
    final hasFilter = filterCount > 0;
    final hasGroup = groupByLabel != null && groupByLabel!.trim().isNotEmpty;

    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Row(
        children: [
          Expanded(
            child: (hasFilter || hasGroup)
                ? Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    crossAxisAlignment: WrapCrossAlignment.center,
                    children: [
                      if (hasFilter)
                        _ActiveFilterPill(isDark: isDark, count: filterCount),
                      if (hasGroup) _GroupByPill(label: groupByLabel!),
                    ],
                  )
                : Text(
                    'No filters applied',
                    style: TextStyle(
                      fontSize: 12,
                      color: isDark
                          ? Colors.white70
                          : Theme.of(
                              context,
                            ).colorScheme.onSurface.withOpacity(0.7),
                      fontWeight: FontWeight.w500,
                    ),
                  ),
          ),
          if (showPagination)
            PaginationControls(
              canGoToPreviousPage: canPrev,
              canGoToNextPage: canNext,
              onPreviousPage: onPrev,
              onNextPage: onNext,
              paginationText: paginationText,
              isDark: isDark,
              theme: Theme.of(context),
            ),
        ],
      ),
    );
  }
}

/// Active filter count pill — solid black with white text, inverted (white
/// with black text) in dark mode so it doesn't vanish into the background.
/// As the events app's "N Active" chip, and the twin of [_GroupByPill].
class _ActiveFilterPill extends StatelessWidget {
  final bool isDark;
  final int count;

  const _ActiveFilterPill({required this.isDark, required this.count});

  @override
  Widget build(BuildContext context) {
    final foreground = isDark ? Colors.black : Colors.white;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: isDark ? Colors.white : Colors.black,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            count.toString(),
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.bold,
              color: foreground,
            ),
          ),
          const SizedBox(width: 5),
          Text('Active', style: TextStyle(fontSize: 12, color: foreground)),
        ],
      ),
    );
  }
}

/// GroupBy indicator pill — the same solid black (white in dark mode) as
/// [_ActiveFilterPill], with a layer icon + truncated label.
class _GroupByPill extends StatelessWidget {
  final String label;

  const _GroupByPill({required this.label});

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final foreground = isDark ? Colors.black : Colors.white;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
      decoration: BoxDecoration(
        color: isDark ? Colors.white : Colors.black,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          HugeIcon(
            icon: HugeIcons.strokeRoundedLayer,
            size: 14,
            color: foreground,
          ),
          const SizedBox(width: 5),
          ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 90),
            child: Text(
              label,
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w500,
                color: foreground,
              ),
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      ),
    );
  }
}
