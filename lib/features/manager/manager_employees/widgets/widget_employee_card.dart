import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:hugeicons/hugeicons.dart';
import 'package:mobo_employees/core/const/all_design.dart';

class WidgetEmployeeCard extends StatelessWidget {
  Widget? child;
  String? employeeName;
  String? employeeJob;
  String? employeePhone;
  String? employeeEmail;
  WidgetEmployeeCard({
    super.key,
    required this.child,
    required this.employeeName,
    required this.employeeJob,
    required this.employeePhone,
    required this.employeeEmail,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
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
          ClipRRect(borderRadius: BorderRadius.circular(10), child: child),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        employeeName.toString(),
                        style: GoogleFonts.manrope(
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                          color: AppColors.colorD14D72,
                        ),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    const SizedBox(width: 6),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 3,
                      ),
                      decoration: BoxDecoration(
                        color: AppColors.color65BA68.withOpacity(.12),
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Text(
                        employeeJob.toString(),
                        style: TextStyle(
                          fontSize: 11,
                          color: AppColors.color65BA68,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ),
                  ],
                ),

                const SizedBox(height: 5),

                Row(
                  children: [
                    HugeIcon(
                      icon: HugeIcons.strokeRoundedCall02,
                      size: 11,
                      color: AppColors.color6A7282,
                    ),
                    SizedBox(width: 6),
                    Text(
                      employeePhone.toString(),
                      style: GoogleFonts.manrope(
                        fontSize: 11,
                        fontWeight: FontWeight.w400,
                        color: AppColors.color6A7282,
                      ),
                    ),
                  ],
                ),

                const SizedBox(height: 5),
                Row(
                  children: [
                    HugeIcon(
                      icon: HugeIcons.strokeRoundedMail01,
                      size: 11,
                      color: AppColors.color6A7282,
                    ),
                    SizedBox(width: 6),
                    Expanded(
                      child: Text(
                        employeeEmail.toString(),
                        style: GoogleFonts.manrope(
                          fontSize: 11,
                          fontWeight: FontWeight.w400,
                          color: AppColors.color6A7282,
                        ),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
