import 'package:intl/intl.dart';

class ModelTimeOffData {
  final int id;

  /// Employee
  final int employeeId;
  final String employeeName;
  final int userId;

  /// Department
  final int departmentId;
  final String departmentName;

  /// Leave
  final String description;
  final String leaveTypeName;
  final String durationDisplay;

  /// Dates
  final DateTime? dateFrom;
  final DateTime? dateTo;
  final String dateFromFormatted;
  final String dateToFormatted;
  final String create_date;

  /// State
  final String state;

  /// Permissions (manager actions)
  final bool canApprove;
  final bool canValidate;
  final bool canRefuse;

  ModelTimeOffData({
    required this.id,
    required this.employeeId,
    required this.userId,
    required this.employeeName,
    required this.departmentId,
    required this.departmentName,
    required this.description,
    required this.leaveTypeName,
    required this.durationDisplay,
    required this.dateFrom,
    required this.dateTo,
    required this.dateFromFormatted,
    required this.dateToFormatted,
    required this.state,
    required this.canApprove,
    required this.canValidate,
    required this.canRefuse,
    required this.create_date,
  });

  factory ModelTimeOffData.fromJson(Map<String, dynamic> json) {
    /// ───── Employee ─────
    int empId = 0;
    String empName = '';

    final employee = json['employee_id'];
    if (employee is Map) {
      empId = (employee['id'] as num?)?.toInt() ?? 0;
      empName = employee['display_name']?.toString() ?? '';
    } else if (employee is List && employee.length >= 2) {
      empId = (employee[0] as num?)?.toInt() ?? 0;
      empName = employee[1]?.toString() ?? '';
    }

    /// ───── Department ─────
    int deptId = 0;
    String deptName = '';

    final department = json['department_id'];
    if (department is Map) {
      deptId = (department['id'] as num?)?.toInt() ?? 0;
      deptName = department['display_name']?.toString() ?? '';
    } else if (department is List && department.length >= 2) {
      deptId = (department[0] as num?)?.toInt() ?? 0;
      deptName = department[1]?.toString() ?? '';
    }

    /// User
    final user = json['user_id'];
    final int userId = user is Map ? (user['id'] as num?)?.toInt() ?? 0 : 0;

    /// ───── Leave Type ─────
    String leaveType = '';
    final holiday = json['holiday_status_id'];
    if (holiday is Map) {
      leaveType = holiday['display_name']?.toString() ?? '';
    } else if (holiday is List && holiday.length >= 2) {
      leaveType = holiday[1]?.toString() ?? '';
    }

    final DateTime? from = _parseOdooDate(json['date_from']);
    final DateTime? to = _parseOdooDate(json['date_to']);
    final DateTime? createDate = _parseOdooDate(json['create_date']);

    return ModelTimeOffData(
      id: (json['id'] as num?)?.toInt() ?? 0,

      employeeId: empId,
      employeeName: empName,
      userId: userId,
      create_date: _formatCreateDate(createDate),
      departmentId: deptId,
      departmentName: deptName,

      description: _stringOrEmpty(json['name']),
      leaveTypeName: leaveType,
      durationDisplay: _stringOrEmpty(
        json['duration_display'] ?? json['number_of_days_display'],
      ),

      dateFrom: from,
      dateTo: to,
      dateFromFormatted: _formatDate(from),
      dateToFormatted: _formatEndDate(to),

      state: _stringOrEmpty(json['state']),

      canApprove: json['can_approve'] == true,
      canValidate: json['can_validate'] == true,
      canRefuse: json['can_refuse'] == true,
    );
  }

  /// ───── Helpers ─────

  static String _stringOrEmpty(dynamic v) {
    if (v == null || v == false) return '';
    return v.toString().trim();
  }

  static DateTime? _parseOdooDate(dynamic v) {
    if (v == null || v == false) return null;
    if (v is DateTime) return v;
    return DateTime.tryParse(v.toString());
  }

  static String _formatDate(DateTime? d) {
    if (d == null) return '-';
    return DateFormat('MMM dd').format(d);
  }

  static String _formatCreateDate(DateTime? d) {
    if (d == null) return '-';
    return DateFormat('MMM dd, yyyy').format(d);
  }

  static String _formatEndDate(DateTime? d) {
    if (d == null) return '-';
    return DateFormat('dd, yyyy').format(d);
  }
}
