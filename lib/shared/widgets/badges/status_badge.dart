import 'package:flutter/material.dart';
import 'package:mobo_employees/core/theme/app_theme.dart';

/// Reusable status badge widget for displaying states with colors
/// Used for transfers, orders, invoices, etc.
class StatusBadge extends StatelessWidget {
  final String status;
  final StatusBadgeStyle? style;

  const StatusBadge({super.key, required this.status, this.style});

  /// Factory for transfer states
  factory StatusBadge.transfer(String state) {
    return StatusBadge(status: state, style: _getTransferStyle(state));
  }

  /// Factory for order states
  factory StatusBadge.order(String state) {
    return StatusBadge(status: state, style: _getOrderStyle(state));
  }

  /// Factory for invoice states
  factory StatusBadge.invoice(String state) {
    return StatusBadge(status: state, style: _getInvoiceStyle(state));
  }

  static StatusBadgeStyle _getTransferStyle(String state) {
    switch (state.toLowerCase()) {
      case 'draft':
        return StatusBadgeStyle(
          label: 'Draft',
          color: StatusColors.orange,
          icon: Icons.edit_outlined,
        );
      case 'waiting':
        return StatusBadgeStyle(
          label: 'Waiting',
          color: StatusColors.orange,
          icon: Icons.hourglass_empty,
        );
      case 'confirmed':
        return StatusBadgeStyle(
          label: 'Waiting', /// Odoo shows 'confirmed' state as 'Waiting'
          color: StatusColors.orange,
          icon: Icons.hourglass_empty,
        );
      case 'assigned':
        return StatusBadgeStyle(
          label: 'Ready',
          color: StatusColors.blue,
          icon: Icons.assignment_turned_in_outlined,
        );
      case 'done':
        return StatusBadgeStyle(
          label: 'Done',
          color: StatusColors.green,
          icon: Icons.check_circle,
        );
      case 'cancel':
      case 'cancelled':
        return StatusBadgeStyle(
          label: 'Cancelled',
          color: StatusColors.red,
          icon: Icons.cancel_outlined,
        );
      default:
        return StatusBadgeStyle(label: state, color: StatusColors.grey);
    }
  }

  static StatusBadgeStyle _getOrderStyle(String state) {
    switch (state.toLowerCase()) {
      case 'draft':
        return StatusBadgeStyle(label: 'Draft', color: StatusColors.orange);
      case 'sent':
        return StatusBadgeStyle(label: 'Sent', color: StatusColors.blue);
      case 'sale':
        return StatusBadgeStyle(label: 'Sale Order', color: StatusColors.green);
      case 'done':
        return StatusBadgeStyle(label: 'Done', color: StatusColors.green);
      case 'cancel':
        return StatusBadgeStyle(label: 'Cancelled', color: StatusColors.red);
      default:
        return StatusBadgeStyle(label: state, color: StatusColors.grey);
    }
  }

  static StatusBadgeStyle _getInvoiceStyle(String state) {
    switch (state.toLowerCase()) {
      case 'draft':
        return StatusBadgeStyle(label: 'Draft', color: StatusColors.orange);
      case 'posted':
        return StatusBadgeStyle(label: 'Posted', color: StatusColors.green);
      case 'paid':
        return StatusBadgeStyle(label: 'Paid', color: StatusColors.green);
      case 'cancel':
        return StatusBadgeStyle(label: 'Cancelled', color: StatusColors.red);
      default:
        return StatusBadgeStyle(label: state, color: StatusColors.grey);
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final badgeStyle =
        style ?? StatusBadgeStyle(label: status, color: StatusColors.grey);
    final Color foreground = isDark ? Colors.white : badgeStyle.color;

    /// Canonical status-badge formula (Mobo UI Style Guide §10): no border,
    /// pill radius, and a colour derived from [StatusColors].
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: isDark
            ? Colors.white.withValues(alpha: 0.15)
            : badgeStyle.color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(AppRadius.statusBadge),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (badgeStyle.icon != null) ...[
            Icon(badgeStyle.icon, size: 14, color: foreground),
            const SizedBox(width: 4),
          ],
          Text(
            badgeStyle.label,
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w600,
              color: foreground,
              letterSpacing: 0.1,
            ),
          ),
        ],
      ),
    );
  }
}

class StatusBadgeStyle {
  final String label;
  final Color color;
  final IconData? icon;

  const StatusBadgeStyle({required this.label, required this.color, this.icon});
}
