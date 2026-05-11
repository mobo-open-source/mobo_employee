import 'package:intl/intl.dart';

class ModelAllocationData {
  final int id;
  final int userId;
  final int employeeId;
  final String employeeName;

  final String leaveTypeName;

  final String durationDisplay;
  final double maxLeaves;
  final double remainingLeaves;

  final DateTime? createDate;
  final String createDateFormatted;
  final String notes;
  final String state;

  final bool canApprove;
  final bool canValidate;
  final bool canRefuse;

  ModelAllocationData({
    required this.id,
    required this.userId,
    required this.employeeId,
    required this.employeeName,
    required this.leaveTypeName,
    required this.durationDisplay,
    required this.maxLeaves,
    required this.notes,
    required this.remainingLeaves,
    required this.createDate,
    required this.createDateFormatted,
    required this.state,
    required this.canApprove,
    required this.canValidate,
    required this.canRefuse,
  });

  factory ModelAllocationData.fromJson(Map<String, dynamic> json) {
    int empId = 0;
    String empName = '';
    int userId = 0;

    final employee = json['employee_id'];

    ///HANDLE INT CASE (IMPORTANT)
    if (employee is int) {
      empId = employee;
    } else if (employee is Map) {
      empId = (employee['id'] as num?)?.toInt() ?? 0;
      empName = employee['display_name'] ?? '';
    } else if (employee is List && employee.length >= 2) {
      empId = (employee[0] as num?)?.toInt() ?? 0;
      empName = employee[1] ?? '';
    }

    final holiday = json['holiday_status_id'];

    String leaveType = '';

    if (holiday is int) {
      leaveType = '';
    } else if (holiday is Map) {
      leaveType = holiday['display_name'] ?? '';
    } else if (holiday is List && holiday.length >= 2) {
      leaveType = holiday[1] ?? '';
    }

    final user = json['user_id'];

    if (user is int) {
      userId = user;
    } else if (user is Map) {
      userId = (user['id'] as num?)?.toInt() ?? 0;
    } else if (user is List && user.length >= 1) {
      userId = (user[0] as num?)?.toInt() ?? 0;
    }

    final DateTime? created = _parseDate(json['write_date']);

    return ModelAllocationData(
      id: (json['id'] as num?)?.toInt() ?? 0,
      userId: userId,
      employeeId: empId,
      notes: _stringOrEmpty(json['notes']),
      employeeName: empName,
      leaveTypeName: leaveType,
      durationDisplay: _stringOrEmpty(json['duration_display']),
      maxLeaves: (json['max_leaves'] as num?)?.toDouble() ?? 0,
      remainingLeaves:
          (json['virtual_remaining_leaves'] as num?)?.toDouble() ?? 0,
      createDate: created,
      createDateFormatted: _formatDate(created),
      state: _stringOrEmpty(json['state']),
      canApprove: json['can_approve'] == true,
      canValidate: json['can_validate'] == true,
      canRefuse: json['can_refuse'] == true,
    );
  }

  static String _stringOrEmpty(dynamic v) {
    if (v == null || v == false) return '';
    return v.toString();
  }

  static DateTime? _parseDate(dynamic v) {
    if (v == null) return null;
    return DateTime.tryParse(v.toString());
  }

  static String _formatDate(DateTime? d) {
    if (d == null) return '-';
    return DateFormat('MMM dd, yyyy').format(d);
  }
}
