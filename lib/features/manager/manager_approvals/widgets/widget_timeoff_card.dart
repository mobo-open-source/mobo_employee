import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:mobo_employees/core/const/all_design.dart';

class WidgetTimeOffCard extends StatelessWidget {
  final String employeeName;
  final String leaveType;
  final String dateRange;
  final String reason;
  final String status;
  final bool statesss;
  final Uint8List? imageBytes;
  final VoidCallback? onValidate;
  final VoidCallback? onRefuse;
  final bool isValidating;
  final bool isRefusing;
  final String actionName;

  const WidgetTimeOffCard({
    super.key,
    required this.employeeName,
    required this.leaveType,
    required this.dateRange,
    required this.reason,
    required this.status,
    required this.statesss,
    required this.imageBytes,
    required this.isValidating,
    required this.isRefusing,
    required this.actionName,
    this.onValidate,
    this.onRefuse,
  });

  @override
  Widget build(BuildContext context) {
    final lowerCaseStatus = status.toLowerCase();
    return Container(
      padding: const EdgeInsets.all(12),
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
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          /// ───── Profile Image ─────
          _profileImage(imageBytes: imageBytes),

          const SizedBox(width: 12),

          /// ───── Content ─────
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                /// ───── Header ─────
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            employeeName,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: GoogleFonts.poppins(
                              fontSize: 15,
                              fontWeight: FontWeight.w500,
                              color: AppColors.color000000,
                            ),
                          ),
                          const SizedBox(height: 3),

                          Text(
                            leaveType,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: GoogleFonts.poppins(
                              fontSize: 13,
                              fontWeight: FontWeight.w400,
                              color: AppColors.color000000,
                            ),
                          ),
                        ],
                      ),
                    ),

                    const SizedBox(width: 4),

                    _statusChip(status),
                  ],
                ),

                /// ───── Date Range ─────
                Text(
                  dateRange,
                  style: GoogleFonts.manrope(
                    fontSize: 11,
                    fontWeight: FontWeight.w400,
                    color: AppColors.color6A7282,
                  ),
                ),
                const SizedBox(height: 8),

                /// ───── Reason ─────

                RichText(
                  text: TextSpan(
                    children: [
                      TextSpan(
                        text: "Reason: ",
                        style: GoogleFonts.manrope(
                          fontSize: 12,
                          fontWeight: FontWeight.w400,
                          color: AppColors.color6A7282,
                        ),
                      ),
                      TextSpan(
                        text: reason,
                        style: GoogleFonts.manrope(
                          fontSize: 12,
                          fontWeight: FontWeight.w400,
                          color: AppColors.color6A7282,
                        ),
                      ),
                    ],
                  ),
                ),

                /// ───── Actions ─────
                !statesss &&
                        lowerCaseStatus != "approved" &&
                        lowerCaseStatus != "refused"
                    ? Row(
                        children: [
                          const SizedBox(height: 14),

                          if (lowerCaseStatus == "approved" ||
                              lowerCaseStatus == "to approve" ||
                              lowerCaseStatus == "confirm" ||
                              lowerCaseStatus == "second approval")
                            Expanded(
                              child: OutlinedButton(
                                onPressed: isRefusing ? null : onRefuse,
                                style: OutlinedButton.styleFrom(
                                  side: BorderSide(
                                    color: AppColors.colorC03355,
                                    width: 1,
                                  ),
                                  padding: const EdgeInsets.symmetric(
                                    vertical: 12,
                                  ),
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(10),
                                  ),
                                ),
                                child: isRefusing
                                    ? const SizedBox(
                                        height: 18,
                                        width: 18,
                                        child: CircularProgressIndicator(
                                          strokeWidth: 2,
                                        ),
                                      )
                                    : Text(
                                        "Refuse",
                                        style: GoogleFonts.poppins(
                                          fontSize: 12,
                                          fontWeight: FontWeight.w500,
                                          color: AppColors.colorC03355,
                                        ),
                                      ),
                              ),
                            ),
                          const SizedBox(width: 10),
                          if (lowerCaseStatus == "to approve" ||
                              lowerCaseStatus == "confirm" ||
                              lowerCaseStatus == "second approval" ||
                              lowerCaseStatus == "refused" ||
                              lowerCaseStatus == "cancelled")
                            Expanded(
                              child: ElevatedButton(
                                onPressed: isValidating ? null : onValidate,
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: AppColors.colorC03355,
                                  padding: const EdgeInsets.symmetric(
                                    vertical: 12,
                                  ),
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(10),
                                  ),
                                  elevation: 0,
                                ),
                                child: isValidating
                                    ? const SizedBox(
                                        height: 18,
                                        width: 18,
                                        child: CircularProgressIndicator(
                                          strokeWidth: 2,
                                          color: Colors.white,
                                        ),
                                      )
                                    : Text(
                                        actionName,
                                        style: GoogleFonts.poppins(
                                          fontSize: 12,
                                          fontWeight: FontWeight.w500,
                                          color: Colors.white,
                                        ),
                                      ),
                              ),
                            ),
                        ],
                      )
                    : const SizedBox.shrink(),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _profileImage({required Uint8List? imageBytes}) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(8),
      child: Container(
        width: 50,
        height: 60,
        color: AppColors.colorEDEDEB,
        child: imageBytes != null
            ? Image.memory(
                imageBytes!,
                fit: BoxFit.cover,
                errorBuilder: (_, __, ___) => _fallbackAvatar(),
              )
            : _fallbackAvatar(),
      ),
    );
  }

  Widget _fallbackAvatar() {
    return Container(
      width: 48,
      height: 48,
      decoration: BoxDecoration(
        color: AppColors.colorEDEDEB,
        borderRadius: BorderRadius.circular(15),
      ),
      alignment: Alignment.center,
      child: Icon(Icons.person, size: 26, color: AppColors.color000000),
    );
  }

  /// ───── Status Chip ─────
  Widget _statusChip(String status) {
    Color bg;
    Color fg;

    switch (status.toLowerCase()) {
      case 'confirm':
      case 'to approve':
        bg = Colors.orange.withOpacity(0.15);
        fg = Colors.orange;
        break;

      case 'second approval':
        bg = Colors.orange.withOpacity(0.15);
        fg = Colors.orange;
        break;

      case 'approved':
        bg = Colors.green.withOpacity(0.15);
        fg = Colors.green;
        break;

      case 'refused':
      case 'cancelled':
        bg = Colors.red.withOpacity(0.15);
        fg = Colors.red;
        break;

      default:
        bg = Colors.grey.withOpacity(0.15);
        fg = Colors.grey;
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(
        status,
        style: GoogleFonts.manrope(
          fontSize: 12,
          fontWeight: FontWeight.w700,
          color: fg,
        ),
      ),
    );
  }
}
