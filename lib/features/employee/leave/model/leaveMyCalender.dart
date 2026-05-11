import 'package:intl/intl.dart';

class LeaveMyCalenderModel {
  final int id;
  final String description;
  final String leaveTypeName;
  final DateTime? dateFrom;
  final DateTime? dateTo;
  final String dateFromFormatted;
  final String dateToFormatted;
  final String state;

  LeaveMyCalenderModel({
    required this.id,
    required this.description,
    required this.leaveTypeName,
    required this.dateFrom,
    required this.dateTo,
    required this.dateFromFormatted,
    required this.dateToFormatted,
    required this.state,
  });

  /// ONLY fromJson
  factory LeaveMyCalenderModel.fromJson(Map<String, dynamic> json) {
    final DateTime? from = _parseOdooDate(json['date_from']);
    final DateTime? to = _parseOdooDate(json['date_to']);

    return LeaveMyCalenderModel(
      id: json['id'] ?? 0,

      /// use display_name (more reliable for calendar view)
      description: cleanDisplayName(json['display_name']),

      /// extract leave type from display_name
      leaveTypeName: _extractLeaveType(json['display_name']),

      dateFrom: from,
      dateTo: to,

      dateFromFormatted: _formatDate(from),
      dateToFormatted: _formatDate(to),

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

  static String cleanDisplayName(dynamic displayName) {
    if (displayName == null || displayName == false) return '';

    String text = displayName.toString();

    if (text.contains('(')) {
      text = text.split('(').first.trim();
    }

    text = text.replaceAll(RegExp(r'\bdni\b'), 'day');

    return text;
  }

  static DateTime? _parseOdooDate(dynamic v) {
    if (v == null || v == false) return null;
    return DateTime.tryParse(v.toString())?.toLocal();
  }

  static String _formatDate(DateTime? d) {
    if (d == null) return '-';
    return DateFormat('dd MMM yyyy').format(d);
  }
}
