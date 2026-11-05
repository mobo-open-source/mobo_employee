import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:hugeicons/hugeicons.dart';
import 'package:mobo_employees/core/const/all_design.dart';
import 'package:mobo_employees/core/theme/app_theme.dart';

class WidgetMyTimeOffPage extends StatefulWidget {
  final String leaveName;
  final String leaveTypeandTime;
  final String status;

  /// Odoo `state` of the request (`draft`, `confirm`, `validate1`,
  /// `validate`, `refuse`, `cancel`) — colours the [status] badge.
  final String state;
  final String reason;
  final String appliedDate;

  const WidgetMyTimeOffPage({
    super.key,
    required this.leaveName,
    required this.leaveTypeandTime,
    required this.status,
    required this.state,
    required this.reason,
    required this.appliedDate,
  });

  @override
  State<WidgetMyTimeOffPage> createState() => _WidgetMyTimeOffPageState();
}

class _WidgetMyTimeOffPageState extends State<WidgetMyTimeOffPage> {
  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final titleColor = isDark ? Colors.white : AppColors.color000000;
    final detailColor = isDark ? Colors.white70 : AppColors.color6D717F;
    final metaColor = isDark ? Colors.white60 : AppColors.color6A7282;
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: isDark ? AppColors.greyShade800Color : Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: AppColors.color000000.withOpacity(.04),
            offset: const Offset(3, 11),
            blurRadius: 8.5,
            spreadRadius: -3,
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          /// Header
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: Text(
                  widget.leaveName,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: GoogleFonts.manrope(
                    fontSize: 14,
                    fontWeight: FontWeight.w500,
                    color: titleColor,
                  ),
                ),
              ),
              const SizedBox(width: 8),
              StatusColors.buildStatusBadge(
                widget.status,
                color: StatusColors.forState(widget.state),
                isDark: isDark,
              ),
            ],
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              HugeIcon(
                icon: HugeIcons.strokeRoundedClock01,
                color: metaColor,
                size: 15,
                strokeWidth: 1,
              ),
              const SizedBox(width: 5),
              Text(
                widget.leaveTypeandTime,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: GoogleFonts.manrope(
                  fontSize: 12,
                  fontWeight: FontWeight.w400,
                  color: detailColor,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              Text(
                "Reason: ${widget.reason}",
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: GoogleFonts.manrope(
                  fontSize: 12,
                  fontWeight: FontWeight.w400,
                  color: detailColor,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Divider(
            endIndent: 5,
            indent: 5,
            color: isDark ? Colors.white12 : AppColors.colorF0F0F0,
            thickness: 1,
          ),

          const SizedBox(height: 8),

          RichText(
            text: TextSpan(
              children: [
                TextSpan(
                  text: "Applied on ",
                  style: GoogleFonts.manrope(
                    fontSize: 11,
                    fontWeight: FontWeight.w400,
                    color: metaColor,
                  ),
                ),
                TextSpan(
                  text: widget.appliedDate,
                  style: GoogleFonts.manrope(
                    fontSize: 11,
                    fontWeight: FontWeight.w400,
                    color: metaColor,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
