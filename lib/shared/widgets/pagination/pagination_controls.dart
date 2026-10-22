import 'package:flutter/material.dart';
import 'package:hugeicons/hugeicons.dart';

/// Reusable pagination controls with prev/next buttons and page info.
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
              color: isDark ? Colors.white70 : Colors.black87,
            ),
          ),
        ),
        const SizedBox(width: 4),
        SizedBox(
          width: 32,
          height: 36,
          child: Material(
            color: Colors.transparent,
            child: InkWell(
              customBorder: const CircleBorder(),
              onTap: canGoToPreviousPage ? onPreviousPage : null,
              child: Center(
                child: HugeIcon(
                  icon: HugeIcons.strokeRoundedArrowLeft01,
                  size: 20,
                  color: canGoToPreviousPage
                      ? (isDark ? Colors.white : Colors.black87)
                      : (isDark ? Colors.grey[600]! : Colors.grey[400]!),
                ),
              ),
            ),
          ),
        ),
        SizedBox(
          width: 32,
          height: 36,
          child: Material(
            color: Colors.transparent,
            child: InkWell(
              customBorder: const CircleBorder(),
              onTap: canGoToNextPage ? onNextPage : null,
              child: Center(
                child: HugeIcon(
                  icon: HugeIcons.strokeRoundedArrowRight01,
                  size: 20,
                  color: canGoToNextPage
                      ? (isDark ? Colors.white : Colors.black87)
                      : (isDark ? Colors.grey[600]! : Colors.grey[400]!),
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }
}
