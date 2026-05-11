import 'package:mobo_employees/core/services/odoo_session_manager.dart';
import '../model/leaveMyCalender.dart';
import '../model/model_time_off_type.dart';

/// Service for fetching leave-related data from the Odoo backend.
///
/// Wraps `hr.leave`, `hr.leave.allocation`, `hr.leave.type`, and `hr.employee`
/// RPC calls used by the time-off feature: dashboard balances, calendar
/// events, available leave types, and employee resolution from the session.
class LeaveService {
  /// Aggregates allocations and leaves for [employeeId] into a dashboard summary.
  ///
  /// Reads `hr.leave.allocation` and `hr.leave` records for the employee and
  /// computes per-type (paid / training) available balances by subtracting
  /// approved and planned days from validated allocations. Pending allocations
  /// (state `confirm` or `validate1`) are counted but not deducted.
  ///
  /// Returns a map with keys: `paid_available`, `paid_valid_until`,
  /// `training_available`, `training_valid_until`, `pending_allocations`.
  Future<Map<String, dynamic>> fetchTimeOffDashboard(int employeeId) async {
    final allocations = await OdooSessionManager.callKwWithCompany({
      'model': 'hr.leave.allocation',
      'method': 'search_read',
      'args': [],
      'kwargs': {
        'domain': [
          ['employee_id', '=', employeeId],
        ],
        'fields': ['state', 'number_of_days', 'holiday_status_id', 'date_to'],
      },
    });

    final leaves = await OdooSessionManager.callKwWithCompany({
      'model': 'hr.leave',
      'method': 'search_read',
      'args': [],
      'kwargs': {
        'domain': [
          ['employee_id', '=', employeeId],
        ],
        'fields': ['state', 'number_of_days', 'holiday_status_id'],
      },
    });

    double paidAllocated = 0;
    double trainingAllocated = 0;
    double paidApproved = 0;
    double trainingApproved = 0;
    double paidPlanned = 0;
    double trainingPlanned = 0;
    String? paidValidUntil;
    String? trainingValidUntil;
    int pendingAllocations = 0;

    for (var a in allocations) {
      final state = a['state'];
      final days = (a['number_of_days'] ?? 0).toDouble();
      final type = a['holiday_status_id']?[1]?.toLowerCase() ?? '';
      final dateTo = a['date_to'];

      if (state == 'validate') {
        if (type.contains('paid')) {
          paidAllocated += days;
          paidValidUntil ??= dateTo;
        } else if (type.contains('training')) {
          trainingAllocated += days;
          trainingValidUntil ??= dateTo;
        }
      } else if (state == 'confirm' || state == 'validate1') {
        pendingAllocations++;
      }
    }

    for (var l in leaves) {
      final state = l['state'];
      final days = (l['number_of_days'] ?? 0).toDouble();
      final type = l['holiday_status_id']?[1]?.toLowerCase() ?? '';

      if (state == 'validate') {
        if (type.contains('paid')) {
          paidApproved += days;
        } else if (type.contains('training')) {
          trainingApproved += days;
        }
      } else if (state == 'confirm' || state == 'validate1') {
        if (type.contains('paid')) {
          paidPlanned += days;
        } else if (type.contains('training')) {
          trainingPlanned += days;
        }
      }
    }

    final paidAvailable = paidAllocated - paidApproved - paidPlanned;
    final trainingAvailable =
        trainingAllocated - trainingApproved - trainingPlanned;

    return {
      "paid_available": paidAvailable,
      "paid_valid_until": paidValidUntil,
      "training_available": trainingAvailable,
      "training_valid_until": trainingValidUntil,
      "pending_allocations": pendingAllocations,
    };
  }

  /// Fetches the time-off dashboard summary for the current session's company.
  ///
  /// Calls `hr.employee.get_time_off_dashboard_data` with the current
  /// timestamp, scoped to the active company. Returns the raw RPC payload,
  /// or `null` if the call throws (errors are swallowed).
  Future fetchMySummary() async {
    try {
      final session = await OdooSessionManager.getCurrentSession();

      final result = await OdooSessionManager.callKwWithCompany(
        {
          'model': 'hr.employee',
          'method': 'get_time_off_dashboard_data',
          'args': [DateTime.now().toIso8601String()],
          'kwargs': {},
        },
        allowedCompanyIds: [session!.companyId],
      );

      return result;
    } catch (_) {}
  }

  /// Returns the current user's leave records as calendar events.
  ///
  /// Queries `hr.leave` filtered by the session's `user_id`. The [from] and
  /// [to] parameters describe the visible calendar window for the caller; they
  /// are not currently passed to the backend, so this returns all of the
  /// user's leaves and the caller is expected to filter client-side.
  ///
  /// Returns an empty list if the session is missing, the response is not a
  /// list, or the call throws.
  Future<List<LeaveMyCalenderModel>> fetchMyLeaveCalendarEvents({
    required DateTime from,
    required DateTime to,
  }) async {
    try {
      final session = await OdooSessionManager.getCurrentSession();
      final userId = session?.userId.toInt();
      final response = await OdooSessionManager.callKwWithCompany({
        'model': 'hr.leave',
        'method': 'search_read',
        'args': [
          [
            ['user_id', '=', userId],
          ],
        ],
        'kwargs': {
          'fields': [
            'id',
            'name',
            'display_name',
            'state',
            'date_from',
            'date_to',
            'holiday_status_id',
            'activity_state',
          ],
          'context': {'uid': userId},
        },
      });

      if (response is! List) return [];

      return response
          .map(
            (e) => LeaveMyCalenderModel.fromJson(Map<String, dynamic>.from(e)),
          )
          .toList();
    } catch (_) {
      return [];
    }
  }

  /// Loads selectable leave types for the current employee, optionally filtered.
  ///
  /// Resolves the current user's employee record and calls
  /// `hr.leave.type.web_search_read` with a domain that excludes types the
  /// employee can't request. On Odoo 19 the domain additionally honours
  /// `requires_allocation`, `has_valid_allocation`, and `allows_negative`
  /// flags. When [text] is non-empty it adds an `ilike` match on
  /// `display_name` for type-ahead search.
  ///
  /// Returns an empty list on any failure.
  static Future<List<ModelTimeOffType>> fetchTimeOffTypes({
    String text = '',
  }) async {
    try {
      final session = await OdooSessionManager.getCurrentSession();
      final userId = session?.userId.toInt();
      final version = session!.odooSession.serverVersion;

      final employee = await OdooSessionManager.callKwWithCompany({
        'model': 'hr.employee',
        'method': 'search_read',
        'args': [
          [
            ['user_id', '=', userId],
          ],
        ],
        'kwargs': {
          'fields': ['id', 'name'],
          'limit': 1,
        },
      });

      final employeeId = employee.isNotEmpty ? employee[0]['id'] : null;

      final response = await OdooSessionManager.callKwWithCompany({
        'model': 'hr.leave.type',
        'method': 'web_search_read',
        'args': [],
        'kwargs': {
          'domain': [
            if (version.contains("19")) '|',
            if (version.contains("19")) ['requires_allocation', '=', false],
            if (version.contains("19")) ['has_valid_allocation', '=', true],
            if (version.contains("19")) '|',
            if (version.contains("19")) ['requires_allocation', '=', false],
            if (version.contains("19")) '&',
            if (version.contains("19")) ['has_valid_allocation', '=', true],
            if (version.contains("19")) '|',
            if (version.contains("19")) ['allows_negative', '=', true],
            ['virtual_remaining_leaves', '>', 0],
            if (text.trim().isNotEmpty) ['display_name', 'ilike', text],
          ],
          'context': {'employee_id': employeeId},
          'specification': {
            'display_name': {},
            'allows_negative': {},
            'has_valid_allocation': {},
            'virtual_remaining_leaves': {},
            'requires_allocation': {},
          },
          'order': 'sequence ASC, id ASC',
        },
      });

      bool parseBool(dynamic value) {
        if (value is bool) return value;
        if (value is String) return value.toLowerCase() == 'true';
        if (value is int) return value == 1;
        return false;
      }

      if (response is Map && response['records'] is List) {
        final records = response['records'] as List;

        return records.map<ModelTimeOffType>((e) {
          final map = Map<String, dynamic>.from(e);

          return ModelTimeOffType(
            id: map['id'] ?? 0,
            displayName: map['display_name'] ?? map['name'] ?? '',
            requiresAllocation: parseBool(map['requires_allocation']),
            employeeRequests: false,
            responsibleIds: [],
            responsibleNames: [],
          );
        }).toList();
      }
      return [];
    } catch (_) {
      return [];
    }
  }

  /// Resolves the `hr.employee` id linked to the currently logged-in user.
  ///
  /// Returns `null` if there is no active session, no user id, or no employee
  /// record matches the user.
  Future<int?> fetchEmployeeId() async {
    final session = await OdooSessionManager.getCurrentSession();
    final userId = session?.userId;

    if (userId == null) return null;

    final result = await OdooSessionManager.callKwWithCompany({
      'model': 'hr.employee',
      'method': 'search_read',
      'args': [],
      'kwargs': {
        'domain': [
          ['user_id', '=', userId],
        ],
        'fields': ['id', 'name'],
        'limit': 1,
      },
    });

    if (result is List && result.isNotEmpty) {
      return result.first['id'];
    }

    return null;
  }
}
