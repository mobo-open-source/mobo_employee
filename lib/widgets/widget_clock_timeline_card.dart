import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:mobo_employees/core/const/all_design.dart';

class WidgetClockTimelineCard extends StatelessWidget {
  final String clockInTime;
  final String clockOutTime;

  WidgetClockTimelineCard({
    super.key,
    required this.clockInTime,
    required this.clockOutTime,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
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
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Column(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [_dot(), _divider(), _belowDot()],
            ),

            const SizedBox(width: 12),

            Expanded(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  _row(
                    label: 'Clock In',
                    time: clockInTime,
                    color: AppColors.colorF59E0B,
                  ),
                  const SizedBox(height: 15),
                  _row(
                    label: 'Clock Out',
                    time: clockOutTime,
                    color: AppColors.color43B75D,
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _dot() => Padding(
    padding: const EdgeInsets.only(top: 5),
    child: Container(
      width: 10,
      height: 10,
      decoration: BoxDecoration(
        color: AppColors.colorC03355,
        shape: BoxShape.circle,
      ),
    ),
  );

  Widget _belowDot() => Padding(
    padding: const EdgeInsets.only(bottom: 5),
    child: Container(
      width: 10,
      height: 10,
      decoration: BoxDecoration(
        color: AppColors.colorC03355,
        shape: BoxShape.circle,
      ),
    ),
  );

  Widget _divider() =>
      Container(width: 1, height: 25, color: AppColors.colorF09DA9);

  Widget _row({
    required String label,
    required String time,
    required Color color,
  }) => Row(
    children: [
      Expanded(
        child: Text(
          label,
          style: GoogleFonts.manrope(fontSize: 14, fontWeight: FontWeight.w400),
        ),
      ),
      Text(
        time,
        style: GoogleFonts.manrope(
          fontSize: 14,
          fontWeight: FontWeight.w700,
          color: color,
        ),
      ),
    ],
  );
}
