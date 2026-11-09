import 'package:intl/intl.dart';
import 'package:mobo_employees/core/services/connectivity_service.dart';
import 'package:mobo_employees/core/services/odoo_session_manager.dart';
import 'package:mobo_employees/shared/services/time_off_type_service.dart';
import '../model/leaveMyCalender.dart';
import '../model/model_time_off_balance.dart';
import '../model/model_time_off_type.dart';

/// Service for fetching leave-related data from the Odoo backend.
///
/// Wraps `hr.leave`, `hr.leave.allocation`, `hr.leave.type` (`hr.work.entry.type`
/// on Odoo 20), and `hr.employee`
/// RPC calls used by the time-off feature: dashboard balances, calendar
/// events, available leave types, and employee resolution from the session.
class LeaveService {
  /// Time off states still awaiting approval: Odoo's "To Approve" and
  /// "Second Approval".
  static const List<String> pendingStates = ['confirm', 'validate1'];

  /// Number of the current user's own time off requests awaiting approval.
  ///
  /// The single source for the "pending requests" figure on both the
  /// dashboard and the Time Off page, so the two always agree. Scoped like
  /// Odoo's "My Time Off" (`user_id = uid`): without it, an HR officer —
  /// who can read every employee's requests — would get the whole
  /// company's pending requests counted as their own.
  static Future<int> fetchMyPendingRequestCount() async {
    final session = await OdooSessionManager.getCurrentSession();
    final userId = session?.userId;
    if (userId == null) return 0;

    final result = await OdooSessionManager.callKwWithCompany({
      'model': 'hr.leave',
      'method': 'search_count',
      'args': [
        [
          ['user_id', '=', userId],
          ['state', 'in', pendingStates],
        ],
      ],
      'kwargs': {},
    });
    return result is int ? result : 0;
  }

  /// The current employee's time off balances and pending allocation
  /// requests — the same figures, from the same server methods, as Odoo's
  /// own Time Off dashboard for this version.
  static Future<TimeOffDashboard> fetchMyTimeOffDashboard() async {
    final majorVersion = await OdooSessionManager.getServerMajorVersion();
    final today = DateFormat('yyyy-MM-dd').format(DateTime.now());

    dynamic entries;
    int pendingAllocations = 0;

    // Odoo's own dashboard always sends `from_dashboard`; without it the
    // server returns every time off type — Odoo 20 lists ~20 empty cards —
    // instead of only those the employee has an allocation for.
    const dashboardContext = {'from_dashboard': true};

    if (majorVersion >= 19) {
      final result = await OdooSessionManager.callKwWithCompany({
        'model': 'hr.employee',
        'method': 'get_time_off_dashboard_data',
        'args': [today],
        'kwargs': {'context': dashboardContext},
      }, activeCompanyFirst: true);
      if (result is Map) {
        entries = result['allocation_data'];
        // Odoo 20 renamed allocation_request_amount to allocations_number
        final pending =
            result['allocations_number'] ?? result['allocation_request_amount'];
        pendingAllocations = pending is num ? pending.toInt() : 0;
      }
    } else {
      entries = await OdooSessionManager.callKwWithCompany({
        'model': 'hr.leave.type',
        'method': 'get_allocation_data_request',
        // 18's dashboard passes hidden_allocations=False so only types
        // flagged "show on dashboard" are listed; 17 has no such flag.
        'args': [today, if (majorVersion == 18) false],
        'kwargs': {'context': dashboardContext},
      }, activeCompanyFirst: true);
      pendingAllocations = await _fetchPendingAllocationCount(majorVersion);
    }

    final balances = entries is List
        ? entries
              .map(TimeOffBalance.fromDashboardEntry)
              .whereType<TimeOffBalance>()
              .toList()
        : <TimeOffBalance>[];
    return TimeOffDashboard(
      balances: balances,
      pendingAllocations: pendingAllocations,
    );
  }

  /// "Pending Allocations" before Odoo 19 folded it into the dashboard call.
  static Future<int> _fetchPendingAllocationCount(int majorVersion) async {
    if (majorVersion == 18) {
      final result = await OdooSessionManager.callKwWithCompany({
        'model': 'hr.employee',
        'method': 'get_allocation_requests_amount',
        'args': [],
        'kwargs': {},
      }, activeCompanyFirst: true);
      return result is int ? result : 0;
    }

    // 17 has no such method; count it the way 18 does.
    final session = await OdooSessionManager.getCurrentSession();
    final userId = session?.userId;
    if (userId == null) return 0;
    final result = await OdooSessionManager.callKwWithCompany({
      'model': 'hr.leave.allocation',
      'method': 'search_count',
      'args': [
        [
          ['employee_id.user_id', '=', userId],
          ['state', '=', 'confirm'],
        ],
      ],
      'kwargs': {},
    });
    return result is int ? result : 0;
  }

  /// Returns the current user's leave records as calendar events.
  ///
  /// Queries `hr.leave` filtered by the session's `user_id`. The [from] and
  /// [to] parameters describe the visible calendar window for the caller; they
  /// are not currently passed to the backend, so this returns all of the
  /// user's leaves and the caller is expected to filter client-side.
  ///
  /// Returns an empty list if the session is missing, the response is not a
  /// list, or the call throws for any reason other than a connectivity
  /// failure, which is rethrown so the page can show it.
  Future<List<LeaveMyCalenderModel>> fetchMyLeaveCalendarEvents({
    required DateTime from,
    required DateTime to,
  }) async {
    try {
      final session = await OdooSessionManager.getCurrentSession();
      final userId = session?.userId.toInt();
      final majorVersion = await OdooSessionManager.getServerMajorVersion();
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
            TimeOffTypeService.typeField(majorVersion),
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
    } catch (e) {
      if (ConnectivityService.isConnectivityError(e)) rethrow;
      return [];
    }
  }

  /// Loads selectable leave types for the current employee, optionally filtered.
  ///
  /// Resolves the current user's employee record and calls
  /// `hr.leave.type.web_search_read` with a domain that excludes types the
  /// employee can't request. On Odoo 19 the domain additionally honours
  /// `requires_allocation`, `has_valid_allocation`, and `allows_negative`
  /// flags; on Odoo 20 the types come from `hr.work.entry.type` via
  /// [TimeOffTypeService]. When [text] is non-empty it adds an `ilike` match
  /// on `display_name` for type-ahead search.
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

      // Odoo 20 replaced hr.leave.type with hr.work.entry.type
      if (await OdooSessionManager.getServerMajorVersion() >= 20) {
        final records = await TimeOffTypeService.fetchSelectableTypes(
          employeeId: employeeId,
          query: text,
        );
        return records
            .map(
              (map) => ModelTimeOffType(
                id: map['id'] ?? 0,
                displayName: map['display_name'] ?? '',
                requiresAllocation: map['requires_allocation'] == true,
                employeeRequests: false,
                responsibleIds: [],
                responsibleNames: [],
              ),
            )
            .toList();
      }

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

            // On 17/18 `requires_allocation` is the long-standing
            // Selection('yes'/'no') field (not the boolean used above for
            // 19), so a type that doesn't require allocation at all (e.g.
            // "Unpaid Leave") must be matched by that string value here —
            // otherwise it has no allocation, `virtual_remaining_leaves`
            // is always 0, and it silently never appears in the picker.
            if (!version.contains("19")) '|',
            if (!version.contains("19")) ['requires_allocation', '=', 'no'],

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
        if (value is String) {
          // `requires_allocation` is Selection('yes'/'no') on 17/18 and
          // boolean-flavoured on 19; accept both spellings.
          final v = value.toLowerCase();
          return v == 'true' || v == 'yes';
        }
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
