import 'package:flutter/material.dart';

/// One group of a grouped list, laid out as mobo Sales' group-by tiles (the
/// quotation / invoice lists): a bordered card whose header shows the group's
/// name, how many records it holds and a chevron, and which — while expanded —
/// shows the group's records directly beneath the header, inset 8px, with no
/// divider and no extra frame.
///
/// [GroupSectionCard] is the other grouped-list card (CRM style: a divider and
/// 16px of padding around the rows); this one suits rows that are cards in
/// their own right, so they don't get a second frame.
class GroupTileCard extends StatelessWidget {
  final String title;

  /// Secondary line under the title, e.g. "3 records".
  final String subtitle;
  final bool isExpanded;
  final VoidCallback onToggle;

  /// The group's records, shown under the header while [isExpanded].
  final Widget? body;

  const GroupTileCard({
    super.key,
    required this.title,
    required this.subtitle,
    required this.isExpanded,
    required this.onToggle,
    this.body,
  });

  static const double _radius = 12;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      decoration: BoxDecoration(
        color: isDark ? Colors.grey[900] : Colors.white,
        borderRadius: BorderRadius.circular(_radius),
        border: Border.all(
          color: isDark
              ? Colors.white.withValues(alpha: 0.08)
              : Colors.black.withValues(alpha: 0.06),
        ),
        boxShadow: [
          if (!isDark)
            BoxShadow(
              blurRadius: 16,
              spreadRadius: 2,
              offset: const Offset(0, 6),
              color: Colors.black.withValues(alpha: 0.08),
            ),
        ],
      ),
      child: Column(
        children: [
          InkWell(
            onTap: onToggle,
            borderRadius: BorderRadius.circular(_radius),
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          title,
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w600,
                            color: isDark ? Colors.white : Colors.black87,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          subtitle,
                          style: TextStyle(
                            fontSize: 14,
                            color: isDark ? Colors.grey[400] : Colors.grey[600],
                          ),
                        ),
                      ],
                    ),
                  ),
                  Icon(
                    isExpanded ? Icons.expand_less : Icons.expand_more,
                    color: isDark ? Colors.grey[400] : Colors.grey[600],
                  ),
                ],
              ),
            ),
          ),
          if (isExpanded && body != null)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              child: body,
            ),
        ],
      ),
    );
  }
}
