import 'package:flutter/material.dart';
import 'package:hugeicons/hugeicons.dart';

/// The record count and previous / next arrows above a paged list.
///
/// Shows only what is useful:
/// * no arrows when everything fits on one page;
/// * on a longer list, an arrow that can't be used is hidden — but keeps its
///   slot, so the other arrow doesn't slide under a thumb that has just tapped.
///
/// Callers leave the whole control out while there is no data, so an empty
/// list shows no count.
class PaginationControls extends StatelessWidget {
  final bool canGoToPreviousPage;
  final bool canGoToNextPage;
  final VoidCallback onPreviousPage;
  final VoidCallback onNextPage;
  final String paginationText;
  final bool isDark;

  const PaginationControls({
    super.key,
    required this.canGoToPreviousPage,
    required this.canGoToNextPage,
    required this.onPreviousPage,
    required this.onNextPage,
    required this.paginationText,
    required this.isDark,
    ThemeData? theme,
  });

  @override
  Widget build(BuildContext context) {
    // A single page still shows its record count; only the arrows, which
    // have nowhere to go, are left out.
    final hasOtherPages = canGoToPreviousPage || canGoToNextPage;

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          height: 36,
          padding: const EdgeInsets.symmetric(horizontal: 12),
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: isDark ? Colors.grey[800] : Colors.grey[100],
            borderRadius: BorderRadius.circular(20),
            border: Border.all(
              color: isDark ? Colors.grey[700]! : Colors.grey[300]!,
              width: 1,
            ),
          ),
          child: Text(
            paginationText,
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w600,
              color: isDark ? Colors.grey[300] : Colors.grey[700],
            ),
          ),
        ),
        if (hasOtherPages) ...[
          const SizedBox(width: 4),
          _arrow(
            icon: HugeIcons.strokeRoundedArrowLeft01,
            enabled: canGoToPreviousPage,
            onTap: onPreviousPage,
          ),
          _arrow(
            icon: HugeIcons.strokeRoundedArrowRight01,
            enabled: canGoToNextPage,
            onTap: onNextPage,
          ),
        ],
      ],
    );
  }

  /// An arrow that can't be used is hidden but keeps its slot, so the other
  /// arrow doesn't slide under a thumb that has just tapped.
  Widget _arrow({
    required List<List<dynamic>> icon,
    required bool enabled,
    required VoidCallback onTap,
  }) {
    return Visibility(
      visible: enabled,
      maintainSize: true,
      maintainAnimation: true,
      maintainState: true,
      child: SizedBox(
        width: 32,
        height: 36,
        child: Material(
          color: Colors.transparent,
          child: InkWell(
            customBorder: const CircleBorder(),
            onTap: enabled ? onTap : null,
            child: Center(
              child: HugeIcon(
                icon: icon,
                size: 20,
                color: isDark ? Colors.white : Colors.black87,
              ),
            ),
          ),
        ),
      ),
    );
  }
}
