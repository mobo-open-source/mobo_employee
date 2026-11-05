import 'dart:math' as math;
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:mobo_employees/core/const/all_design.dart';
import 'package:mobo_employees/core/theme/app_theme.dart';

/// One attendance as the table shows it, already formatted.
class AttendanceTableEntry {
  final String name;

  /// The employee's photo; initials in a brand circle while there is none.
  final Uint8List? avatar;

  /// The day of the check-in, e.g. "Nov 05".
  final String date;
  final String checkIn;
  final String checkOut;

  /// The check-out's day, only for a shift that ended on a later day than it
  /// began.
  final String? checkOutDate;
  final String worked;

  const AttendanceTableEntry({
    required this.name,
    required this.avatar,
    required this.date,
    required this.checkIn,
    required this.checkOut,
    required this.worked,
    this.checkOutDate,
  });
}

/// The manager's attendance list (ungrouped), as a card: a full-width heading
/// band over rows of avatar, name and day, with the check-in, check-out and
/// worked times — bold — in columns of their own.
///
/// The heading is white, like the card — a rule under it, not a tinted band or
/// a bordered box — and the rows are separated by hairlines.
///
/// Sized to read easily rather than to squeeze in: 60dp rows, a 34dp photo,
/// 13dp text, and columns with room around them. The table is wider than a
/// phone, so it is swiped sideways (the Worked column is a swipe away); on a
/// wider card the employee column takes the extra.
class AttendanceTable extends StatelessWidget {
  final List<AttendanceTableEntry> entries;

  const AttendanceTable({super.key, required this.entries});

  static const double headerHeight = 44;
  static const double rowHeight = 60;
  static const double avatarSize = 34;
  static const double radius = 18;

  /// Side inset of the heading and of every row.
  static const double inset = 16;

  /// Room for each column. They are deliberately roomy — a name and its day
  /// side by side, and a time with air either side — so on a phone the table
  /// is wider than the card and is swiped sideways, rather than squeezed until
  /// the columns touch. On a wider card the employee column takes the extra.
  static const double employeeMinWidth = 214;
  static const double checkInWidth = 96;
  static const double checkOutWidth = 96;
  static const double workedWidth = 84;

  /// Narrower than this and the table scrolls sideways.
  static const double minTableWidth =
      employeeMinWidth + checkInWidth + checkOutWidth + workedWidth + inset * 2;

  static const Color _ink = Color(0xFF0F172A);
  static const Color _muted = Color(0xFF64748B);
  static const Color _headerRule = Color(0xFFE2E8F0);
  static const Color _rowRule = Color(0xFFF1F5F9);

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Container(
      clipBehavior: Clip.antiAlias,
      decoration: BoxDecoration(
        color: isDark ? Colors.grey[850] : Colors.white,
        borderRadius: BorderRadius.circular(radius),
        boxShadow: const [AppShadows.cardShadow],
      ),
      child: LayoutBuilder(
        builder: (context, constraints) {
          final width = math.max(constraints.maxWidth, minTableWidth);
          return SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: SizedBox(
              width: width,
              child: Column(
                children: [
                  _header(isDark),
                  for (var i = 0; i < entries.length; i++)
                    _row(entries[i], isDark, isLast: i == entries.length - 1),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  /// The column headings: capitals, bold, on the card's own colour (white; the
  /// dark card grey in dark mode) with a rule under them.
  Widget _header(bool isDark) {
    final style = GoogleFonts.inter(
      fontSize: 12,
      fontWeight: FontWeight.w700,
      letterSpacing: 0.4,
      color: isDark ? Colors.white : _ink,
    );
    // Scaled down to its column if it is ever wider than it, never clipped.
    Widget heading(String text, double width) => SizedBox(
      width: width,
      child: FittedBox(
        fit: BoxFit.scaleDown,
        child: Text(text, maxLines: 1, style: style),
      ),
    );

    return Container(
      height: headerHeight,
      padding: const EdgeInsets.symmetric(horizontal: inset),
      decoration: BoxDecoration(
        color: isDark ? Colors.grey[850] : Colors.white,
        border: Border(
          bottom: BorderSide(color: isDark ? Colors.grey[700]! : _headerRule),
        ),
      ),
      child: Row(
        children: [
          Expanded(child: Text('EMPLOYEE', maxLines: 1, style: style)),
          heading('CHECK IN', checkInWidth),
          heading('CHECK OUT', checkOutWidth),
          heading('WORKED', workedWidth),
        ],
      ),
    );
  }

  Widget _row(AttendanceTableEntry entry, bool isDark, {required bool isLast}) {
    final ink = isDark ? Colors.white : _ink;
    final muted = isDark ? Colors.grey[400]! : _muted;
    final timeStyle = GoogleFonts.inter(
      fontSize: 13,
      fontWeight: FontWeight.w600,
      color: ink,
    );

    Widget time(String text, double width, {String? caption}) => SizedBox(
      width: width,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // One line always: scaled down to the column if it is ever too wide,
          // never wrapped onto a second.
          FittedBox(
            fit: BoxFit.scaleDown,
            child: Text(text, maxLines: 1, softWrap: false, style: timeStyle),
          ),
          if (caption != null)
            Text(
              caption,
              style: GoogleFonts.inter(
                fontSize: 10,
                fontWeight: FontWeight.w500,
                color: muted,
              ),
            ),
        ],
      ),
    );

    return Container(
      height: rowHeight,
      padding: const EdgeInsets.symmetric(horizontal: inset),
      decoration: BoxDecoration(
        border: isLast
            ? null
            : Border(
                bottom: BorderSide(
                  color: isDark ? Colors.grey[800]! : _rowRule,
                ),
              ),
      ),
      child: Row(
        children: [
          Expanded(
            child: Row(
              children: [
                _Avatar(name: entry.name, bytes: entry.avatar),
                const SizedBox(width: 10),
                Flexible(
                  child: Text(
                    entry.name,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: GoogleFonts.inter(
                      fontSize: 13,
                      fontWeight: FontWeight.w500,
                      color: ink,
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                Text(
                  entry.date,
                  maxLines: 1,
                  style: GoogleFonts.inter(
                    fontSize: 11,
                    fontWeight: FontWeight.w500,
                    color: muted,
                  ),
                ),
              ],
            ),
          ),
          time(entry.checkIn, checkInWidth),
          time(entry.checkOut, checkOutWidth, caption: entry.checkOutDate),
          time(entry.worked, workedWidth),
        ],
      ),
    );
  }
}

/// The employee's photo in a circle, or their initials on the brand colour.
class _Avatar extends StatelessWidget {
  final String name;
  final Uint8List? bytes;

  const _Avatar({required this.name, required this.bytes});

  String get _initials =>
      name.trim().isEmpty ? '--' : name.trim().substring(0, 1).toUpperCase();

  @override
  Widget build(BuildContext context) {
    final fallback = Center(
      child: Text(
        _initials,
        style: const TextStyle(
          color: Colors.white,
          fontSize: 13,
          fontWeight: FontWeight.w600,
        ),
      ),
    );

    return Container(
      width: AttendanceTable.avatarSize,
      height: AttendanceTable.avatarSize,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: AppColors.colorE53E5A,
      ),
      clipBehavior: Clip.antiAlias,
      child: bytes != null && bytes!.isNotEmpty
          ? Image.memory(
              bytes!,
              fit: BoxFit.cover,
              errorBuilder: (_, __, ___) => fallback,
            )
          : fallback,
    );
  }
}
