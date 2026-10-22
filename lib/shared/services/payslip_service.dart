import 'package:intl/intl.dart';
import 'package:mobo_employees/core/services/connectivity_service.dart';
import 'package:mobo_employees/core/services/odoo_session_manager.dart';

/// One payslip, as shown on the dashboards.
class PayslipInfo {
  final DateTime? dateFrom;
  final String state;

  /// The state's label as the server names it (e.g. "Waiting", "Paid").
  final String stateLabel;

  /// Whether the payslip is final (validated or paid).
  final bool isConfirmed;
  final double? netWage;

  /// ISO code of the payslip currency, e.g. `INR`.
  final String? currencyCode;

  const PayslipInfo({
    required this.dateFrom,
    required this.state,
    required this.stateLabel,
    required this.isConfirmed,
    this.netWage,
    this.currencyCode,
  });

  /// Month the payslip covers, e.g. "October 2026".
  String get periodLabel =>
      dateFrom == null ? '' : DateFormat('MMMM yyyy').format(dateFrom!);
}

/// The signed-in employee's payslip figures for the dashboard.
class EmployeePayslipSummary {
  /// Most recent payslip in any state but cancelled.
  final PayslipInfo? latest;

  /// Most recent final payslip: the salary last credited.
  final PayslipInfo? lastCredited;

  /// Number of final payslips.
  final int confirmedCount;

  const EmployeePayslipSummary({
    required this.latest,
    required this.lastCredited,
    required this.confirmedCount,
  });
}

/// Reads payslips (`hr.payslip`) for the dashboards.
///
/// Payroll is an optional Enterprise app, and payslips are readable only by
/// payroll officers and the employee they belong to. Every method returns
/// null when the model is missing or the user may not read it, so callers
/// can hide their payslip figures instead of showing zeros. Connectivity
/// failures are rethrown, like the other dashboard fetches.
class PayslipService {
  static const String _model = 'hr.payslip';

  /// States of a final payslip. Older versions call the validated state
  /// `done`; the set is matched against the server's own selection.
  static const Set<String> _finalStates = {'done', 'validated', 'paid'};

  /// States of a payslip still being prepared or rejected, for servers whose
  /// selection has none of [_finalStates].
  static const Set<String> _nonFinalStates = {'draft', 'verify', 'cancel'};

  /// The current employee's latest payslip, last credited salary and number
  /// of final payslips.
  static Future<EmployeePayslipSummary?> fetchEmployeeSummary(
    int employeeId,
  ) async {
    final schema = await _readSchema();
    if (schema == null) return null;

    Future<dynamic> latestIn(List<dynamic> stateDomain) =>
        OdooSessionManager.callKwWithCompany({
          'model': _model,
          'method': 'search_read',
          'args': [
            [
              ['employee_id', '=', employeeId],
              stateDomain,
            ],
          ],
          'kwargs': {
            'fields': schema.readFields,
            'order': 'date_from desc, id desc',
            'limit': 1,
          },
        });

    try {
      final results = await Future.wait([
        latestIn(['state', '!=', 'cancel']),
        latestIn(['state', 'in', schema.finalStates.toList()]),
        OdooSessionManager.callKwWithCompany({
          'model': _model,
          'method': 'search_count',
          'args': [
            [
              ['employee_id', '=', employeeId],
              ['state', 'in', schema.finalStates.toList()],
            ],
          ],
          'kwargs': {},
        }),
      ]);
      return EmployeePayslipSummary(
        latest: schema.parseFirst(results[0]),
        lastCredited: schema.parseFirst(results[1]),
        confirmedCount: results[2] is int ? results[2] as int : 0,
      );
    } catch (e) {
      if (ConnectivityService.isConnectivityError(e)) rethrow;
      return null;
    }
  }

  /// Number of payslips, in any state but cancelled, covering [month] for
  /// the manager's direct reports.
  static Future<int?> fetchTeamCountForMonth({
    required int managerUserId,
    required DateTime month,
  }) async {
    final schema = await _readSchema();
    if (schema == null) return null;

    final format = DateFormat('yyyy-MM-dd');
    final firstDay = DateTime(month.year, month.month, 1);
    final lastDay = DateTime(month.year, month.month + 1, 0);
    try {
      final count = await OdooSessionManager.callKwWithCompany({
        'model': _model,
        'method': 'search_count',
        'args': [
          [
            ['employee_id.parent_id.user_id', '=', managerUserId],
            ['date_from', '<=', format.format(lastDay)],
            ['date_to', '>=', format.format(firstDay)],
            ['state', '!=', 'cancel'],
          ],
        ],
        'kwargs': {},
      });
      return count is int ? count : 0;
    } catch (e) {
      if (ConnectivityService.isConnectivityError(e)) rethrow;
      return null;
    }
  }

  /// Fields and state labels of `hr.payslip` on this server, or null when
  /// Payroll isn't installed.
  static Future<_PayslipSchema?> _readSchema() async {
    final dynamic fields;
    try {
      fields = await OdooSessionManager.callKwWithCompany({
        'model': _model,
        'method': 'fields_get',
        'args': [],
        'kwargs': {
          'allfields': [
            'date_from',
            'date_to',
            'state',
            'net_wage',
            'currency_id',
          ],
          'attributes': ['selection'],
        },
      });
    } catch (e) {
      if (ConnectivityService.isConnectivityError(e)) rethrow;
      return null;
    }
    if (fields is! Map ||
        !fields.containsKey('state') ||
        !fields.containsKey('date_from') ||
        !fields.containsKey('date_to')) {
      return null;
    }

    final stateLabels = <String, String>{};
    final selection = (fields['state'] as Map?)?['selection'];
    if (selection is List) {
      for (final option in selection) {
        if (option is List && option.length >= 2) {
          stateLabels[option[0].toString()] = option[1].toString();
        }
      }
    }

    var finalStates = _finalStates.intersection(stateLabels.keys.toSet());
    if (finalStates.isEmpty) {
      finalStates = stateLabels.keys.toSet().difference(_nonFinalStates);
    }

    return _PayslipSchema(
      readFields: [
        'date_from',
        'state',
        if (fields.containsKey('net_wage')) 'net_wage',
        if (fields.containsKey('currency_id')) 'currency_id',
      ],
      stateLabels: stateLabels,
      finalStates: finalStates,
    );
  }
}

class _PayslipSchema {
  final List<String> readFields;
  final Map<String, String> stateLabels;
  final Set<String> finalStates;

  const _PayslipSchema({
    required this.readFields,
    required this.stateLabels,
    required this.finalStates,
  });

  PayslipInfo? parseFirst(dynamic records) {
    if (records is! List || records.isEmpty) return null;
    final record = Map<String, dynamic>.from(records.first as Map);
    final state = record['state']?.toString() ?? '';
    final dateFrom = record['date_from'];
    final netWage = record['net_wage'];
    return PayslipInfo(
      dateFrom: dateFrom is String ? DateTime.tryParse(dateFrom) : null,
      state: state,
      stateLabel: stateLabels[state] ?? state,
      isConfirmed: finalStates.contains(state),
      netWage: netWage is num ? netWage.toDouble() : null,
      currencyCode: _many2oneName(record['currency_id']),
    );
  }

  static String? _many2oneName(dynamic value) {
    if (value is List && value.length >= 2) return value[1]?.toString();
    if (value is Map) return value['display_name']?.toString();
    return null;
  }
}
