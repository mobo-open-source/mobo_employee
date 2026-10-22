import 'package:intl/intl.dart';

class LeaveCalendarEvent {
  final int id;
  final String description;
  final String leaveTypeName;
  final DateTime? dateFrom;
  final DateTime? dateTo;
  final String dateFromFormatted;
  final String dateToFormatted;
  final String state;
  final String durationDisplay;

  LeaveCalendarEvent({
    required this.id,
    required this.description,
    required this.leaveTypeName,
    required this.dateFrom,
    required this.dateTo,
    required this.dateFromFormatted,
    required this.dateToFormatted,
    required this.state,
    required this.durationDisplay,
  });

  /// ONLY fromJson
  factory LeaveCalendarEvent.fromJson(Map<String, dynamic> json) {
    /// Odoo 20 replaced start/stop_datetime with the request's start/end
    /// dates (the end date is inclusive).
    final DateTime? from = _parseOdooDate(
      json['start_datetime'] ?? json['request_date_from'],
    );
    final DateTime? to = _parseOdooDate(
      json['stop_datetime'] ?? json['request_date_to'],
    );

    return LeaveCalendarEvent(
      id: json['id'] ?? 0,

      /// use display_name (more reliable for calendar view)
      description: _extractDescription(json['display_name']),

      /// extract leave type from display_name
      leaveTypeName: _extractLeaveType(json['display_name']),

      dateFrom: from,
      dateTo: to,

      dateFromFormatted: _formatDate(from),
      dateToFormatted: _formatDate(to),
      durationDisplay: _stringOrDash(json['duration_display']),

      state: _stringOrDash(json['state']),
    );
  }

  /// ───── helpers ─────

  static String _extractLeaveType(dynamic displayName) {
    if (displayName == null) return '';

    final text = displayName.toString();

    if (text.contains(':')) {
      final parts = text.split(':').first;
      final words = parts.split(' ');
      if (words.length > 1) {
        return words.sublist(1).join(' ');
      }
    }

    return '';
  }

  static String _stringOrDash(dynamic v) {
    if (v == null || v == false) return '';
    final s = v.toString().trim();
    return s.isEmpty ? '' : s;
  }

  static String _extractDescription(dynamic displayName) {
    if (displayName == null || displayName == false) return '';

    final text = displayName.toString().trim();

    /// Split on ":" and take the first part
    if (text.contains(':')) {
      return text.split(':').first.trim();
    }

    return text;
  }

  /// Odoo sends datetimes as naive UTC strings ("2026-10-25 18:30:00").
  /// Parsed as-is they read as local time, so a leave starting at local
  /// midnight (18:30 UTC the day before, e.g. Odoo 20's full-day requests)
  /// landed on the previous day in the calendar.
  static DateTime? _parseOdooDate(dynamic v) {
    if (v == null || v == false) return null;
    final raw = v.toString().trim();
    if (raw.isEmpty) return null;
    /// Date-only values have no clock to shift; Dart can't parse "…Z" on them.
    final needsUtcMarker =
        raw.contains(':') &&
        !raw.endsWith('Z') &&
        !RegExp(r'[+-]\d{2}:?\d{2}$').hasMatch(raw);
    return DateTime.tryParse(needsUtcMarker ? '${raw}Z' : raw)?.toLocal();
  }

  static String _formatDate(DateTime? d) {
    if (d == null) return '-';
    return DateFormat('dd MMM yyyy').format(d);
  }
}
