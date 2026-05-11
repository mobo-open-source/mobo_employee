import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:hugeicons/hugeicons.dart';
import 'package:mobo_employees/core/const/all_design.dart';

class WidgetMyTimeOffPage extends StatefulWidget {
  final String leaveName;
  final String leaveTypeandTime;
  final String status;
  final String reason;
  final String appliedDate;

  const WidgetMyTimeOffPage({
    super.key,
    required this.leaveName,
    required this.leaveTypeandTime,
    required this.status,
    required this.reason,
    required this.appliedDate,
  });

  @override
  State<WidgetMyTimeOffPage> createState() => _WidgetMyTimeOffPageState();
}

class _WidgetMyTimeOffPageState extends State<WidgetMyTimeOffPage> {
  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
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
              Text(
                widget.leaveName,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: GoogleFonts.manrope(
                  fontSize: 14,
                  fontWeight: FontWeight.w500,
                  color: AppColors.color000000,
                ),
              ),
              _statusChip(widget.status),
            ],
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              HugeIcon(
                icon: HugeIcons.strokeRoundedClock01,
                color: AppColors.color6A7282,
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
                  color: AppColors.color6D717F,
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
                  color: AppColors.color6D717F,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Divider(
            endIndent: 5,
            indent: 5,
            color: AppColors.colorF0F0F0,
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
                    color: AppColors.color6A7282,
                  ),
                ),
                TextSpan(
                  text: widget.appliedDate,
                  style: GoogleFonts.manrope(
                    fontSize: 11,
                    fontWeight: FontWeight.w400,
                    color: AppColors.color6A7282,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  /// Status Chip
  Widget _statusChip(String status) {
    Color bgColor;
    Color textColor;

    switch (status.toLowerCase()) {
      case "cancelled":
        bgColor = AppColors.greyShade700Color.withOpacity(0.15);
        textColor = AppColors.greyShade700Color;
        break;
      case "to approve":
        bgColor = AppColors.colorF59E0B.withOpacity(0.15);
        textColor = AppColors.colorF59E0B;

        break;
      case "rejected":
        bgColor = AppColors.colorFF0700.withOpacity(0.15);
        textColor = AppColors.colorFF0700;
        break;
      case "approved":
        bgColor = AppColors.color22C55E.withOpacity(0.15);
        textColor = AppColors.color22C55E;
        break;
      default:
        bgColor = Colors.orange.withOpacity(0.15);
        textColor = Colors.orange;
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(
        status,
        style: GoogleFonts.poppins(
          fontSize: 11,
          fontWeight: FontWeight.w500,
          color: textColor,
        ),
      ),
    );
  }
}
