import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:hugeicons/hugeicons.dart';
import 'package:mobo_employees/core/const/all_design.dart';

class DashboardStatCard extends StatelessWidget {
  final List<List<dynamic>> icon;
  final Color? color;
  final String count;
  final String title;
  final String subtitle;

  const DashboardStatCard({
    super.key,
    required this.icon,
    required this.count,
    required this.color,
    required this.title,
    required this.subtitle,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        boxShadow: [
          BoxShadow(
            color: AppColors.color000000.withOpacity(.04),
            offset: const Offset(3, 11),
            blurRadius: 8.5,
            spreadRadius: -3,
          ),
        ],
        color: AppColors.whiteColor,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.colorEDEDEB),
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.start,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.start,
            children: [
              HugeIcon(icon: icon, color: color, size: 18),
              const SizedBox(width: 6),
              Text(
                count,

                style: GoogleFonts.manrope(
                  fontSize: 20,
                  fontWeight: FontWeight.w500,
                  color: AppColors.color000000,
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Text(
            title,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: GoogleFonts.manrope(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: AppColors.color616161,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            subtitle,
            textAlign: TextAlign.center,
            style: GoogleFonts.manrope(
              fontSize: 10,
              fontWeight: FontWeight.w400,
              color: AppColors.Color4E4E4E,
            ),
          ),
        ],
      ),
    );
  }
}
