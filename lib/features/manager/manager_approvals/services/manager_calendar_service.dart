import 'dart:convert';

import 'package:mobo_employees/core/services/odoo_session_manager.dart';
import 'package:mobo_employees/features/manager/manager_approvals/models/model_allocation_data.dart';
import 'package:mobo_employees/features/manager/manager_approvals/models/model_leave_calendar_event.dart';
import 'package:mobo_employees/features/manager/manager_approvals/models/model_time_off_add_employees.dart';
import 'package:mobo_employees/features/manager/manager_approvals/models/model_time_off_add_time_off_type.dart';
import 'package:mobo_employees/features/manager/manager_approvals/models/model_timeoff_data.dart';

/// Service class for managing calendar and leave-related operations for managers.
///
/// This service provides methods to fetch leave summaries, calendar events,
/// allocation details, and perform approval actions through the Odoo backend.
class ManagerCalendarService {
  /// Fetches the time-off dashboard summary for the current user from Odoo.
  ///
  /// Returns a [dynamic] containing dashboard data such as leave balances and request counts.
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
    } catch (e) {}
  }

  /// Fetches a summary of time-off balances (PTO and Compensatory) from Odoo.
  ///
  /// Handles logic for different Odoo versions (19, 18, and older).
  /// Returns a [Map<String, double>] with keys like 'virtual_remaining_leaves',
  /// 'max_leaves', 'pending_leaves', etc.
  static Future<Map<String, double>> fetchTimeOffSummary() async {
    final session = await OdooSessionManager.getCurrentSession();
    final client = await OdooSessionManager.getClient();
    final String serverVersionString = client!.sessionId!.serverVersion;
    final int majorVersion = int.parse(serverVersionString.split('.').first);

    /// ---------------- ODOO 19 ----------------
    if (majorVersion >= 19) {
      final result = await OdooSessionManager.callKwWithCompany(
        {
          'model': 'hr.employee',
          'method': 'get_time_off_dashboard_data',
          'args': [],
          'kwargs': {},
        },
        allowedCompanyIds: [session!.companyId],
      );
      final allocationData = result['allocation_data'] as List<dynamic>?;

      double ptoRemaining = 0;
      double ptoMax = 0;
      double ptoPending = 0;
      double compRemaining = 0;
      double compMaxLeaves = 0;

      final double allocationRequestAmount =
          (result['allocation_request_amount'] as num?)?.toDouble() ?? 0;

      if (allocationData != null) {
        for (var item in allocationData) {
          final String leaveType = item[0];
          final Map<String, dynamic> data = item[1];

          if (leaveType == 'Paid Time Off') {
            ptoRemaining =
                (data['virtual_remaining_leaves'] as num?)?.toDouble() ?? 0;

            ptoMax = (data['max_leaves'] as num?)?.toDouble() ?? 0;

            ptoPending = (data['leaves_requested'] as num?)?.toDouble() ?? 0;
          }

          if (leaveType == 'Compensatory Days') {
            compRemaining =
                (data['virtual_remaining_leaves'] as num?)?.toDouble() ?? 0;

            compMaxLeaves = (data['max_leaves'] as num?)?.toDouble() ?? 0;
          }
        }
      }

      return {
        'virtual_remaining_leaves': ptoRemaining,
        'max_leaves': ptoMax,
        'pending_leaves': ptoPending,
        'compensatory_leaves': compRemaining,
        'compensatory_max_leaves': compMaxLeaves,
        'allocation_request_amount': allocationRequestAmount,
      };
    }
    /// ---------------- ODOO 18 ----------------
    else if (majorVersion == 18) {
      final result = await OdooSessionManager.callKwWithCompany(
        {
          'model': 'hr.leave.type',
          'method': 'search_read',
          'args': [],
          'kwargs': {'fields': []},
        },
        allowedCompanyIds: [session!.companyId],
      );
      final requestCount = await fetchPendingAllocationRequestCount(
        session.companyId,
      );

      double ptoRemaining = 0;
      double ptoMax = 0;
      double compRemaining = 0;
      double compMaxLeaves = 0;

      if (result is List) {
        for (var item in result) {
          final data = Map<String, dynamic>.from(item);
          final name = data['name'];

          if (name == "Paid Time Off") {
            ptoRemaining =
                (data['virtual_remaining_leaves'] as num?)?.toDouble() ?? 0;

            ptoMax = (data['max_leaves'] as num?)?.toDouble() ?? 0;
          }

          if (name == "Compensatory Days") {
            compRemaining =
                (data['virtual_remaining_leaves'] as num?)?.toDouble() ?? 0;
            compMaxLeaves = (data['max_leaves'] as num?)?.toDouble() ?? 0;
          }
        }
      }

      return {
        'virtual_remaining_leaves': ptoRemaining,
        'max_leaves': ptoMax,
        'pending_leaves': 0,
        'compensatory_leaves': compRemaining,
        'compensatory_max_leaves': compMaxLeaves,
        'allocation_request_amount': requestCount.toDouble(),
      };
    } else {
      final result = await OdooSessionManager.callKwWithCompany(
        {
          'model': 'hr.leave.type',
          'method': 'search_read',
          'args': [],
          'kwargs': {
            'fields': [
              'name',
              'virtual_remaining_leaves',
              'max_leaves',
              'allocation_count',
            ],
          },
        },
        allowedCompanyIds: [session!.companyId],
      );

      double ptoRemaining = 0;
      double ptoMax = 0;
      double compRemaining = 0;
      double compMaxLeaves = 0;

      if (result is List) {
        for (var item in result) {
          final data = Map<String, dynamic>.from(item);
          final name = data['name'];

          if (name == "Paid Time Off") {
            ptoRemaining =
                (data['virtual_remaining_leaves'] as num?)?.toDouble() ?? 0;

            ptoMax = (data['max_leaves'] as num?)?.toDouble() ?? 0;
          }

          if (name == "Compensatory Days") {
            compRemaining =
                (data['virtual_remaining_leaves'] as num?)?.toDouble() ?? 0;

            compMaxLeaves = (data['max_leaves'] as num?)?.toDouble() ?? 0;
          }
        }
      }

      final requestCount = await fetchPendingAllocationRequestCount(
        session.companyId,
      );

      return {
        'virtual_remaining_leaves': ptoRemaining,
        'max_leaves': ptoMax,
        'pending_leaves': 0,
        'compensatory_leaves': compRemaining,
        'compensatory_max_leaves': compMaxLeaves,
        'allocation_request_amount': requestCount.toDouble(),
      };
    }
  }

  /// Fetches the count of pending leave allocation requests for the current user.
  ///
  /// Specifically used for Odoo versions where a direct dashboard API might not be available.
  static Future<int> fetchPendingAllocationRequestCount(int companyIDs) async {
    final odooClient = await OdooSessionManager.callKwWithCompany;
    final session = await OdooSessionManager.getCurrentSession();
    final userId = session?.userId;

    int pendingAllocations = 0;

    final userResponse = await odooClient(
      {
        'model': 'res.users',
        'method': 'search_read',
        'args': [
          [
            ['id', '=', userId],
          ],
        ],
        'kwargs': {
          'fields': ['employee_id'],
        },
      },
      allowedCompanyIds: [companyIDs],
    );

    if (userResponse is! List || userResponse.isEmpty) {
      return 0;
    }

    final employeeId = userResponse.first['employee_id']?[0];

    if (employeeId == null) {
      return 0;
    }

    /// 2️⃣ Fetch allocations for that employee
    final allocations = await odooClient(
      {
        'model': 'hr.leave.allocation',
        'method': 'search_read',
        'args': [],
        'kwargs': {
          'domain': [
            ['employee_id', '=', employeeId],
          ],
          'fields': [],
        },
      },
      allowedCompanyIds: [companyIDs],
    );

    /// 3️⃣ Count pending allocations
    if (allocations is List) {
      for (var a in allocations) {
        final state = a['state'];

        if (state == 'confirm' || state == 'validate1') {
          pendingAllocations++;
        }
      }
    }

    return pendingAllocations;
  }

  /// Fetches the base64-encoded profile image of an employee by their user ID.
  static Future<String?> fetchEmployeeUserProfileImage(int userId) async {
    try {
      final odooClient = await OdooSessionManager.callKwWithCompany;

      final response = await odooClient({
        'model': 'hr.employee',
        'method': 'search_read',
        'args': [],
        'kwargs': {
          'domain': [
            ['id', '=', userId],
          ],
          'fields': ['image_128'],
        },
      });

      if (response is List && response.isNotEmpty) {
        return response.first['image_128'];
      }

      return null;
    } catch (e) {
      return null;
    }
  }

  /// Fetches leave calendar events for the currently logged-in user.
  static Future<List<LeaveCalendarEvent>> fetchMyLeaveCalendarEvents({
    required DateTime from,
    required DateTime to,
  }) async {
    try {
      final odooClient = await OdooSessionManager.callKwWithCompany;
      final session = await OdooSessionManager.getCurrentSession();
      final userId = session?.userId.toInt();
      final response = await odooClient({
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
          .map((e) => LeaveCalendarEvent.fromJson(Map<String, dynamic>.from(e)))
          .toList();
    } catch (e, stackTrace) {
      return [];
    }
  }

  /// Fetches all leave calendar events within a date range, typically for manager views.
  static Future<List<LeaveCalendarEvent>> fetchLeaveCalendarEvents({
    required DateTime from,
    required DateTime to,
  }) async {
    try {
      final odooClient = await OdooSessionManager.callKwWithCompany;
      final session = await OdooSessionManager.getCurrentSession();
      final client = await OdooSessionManager.getClient();
      final String serverVersionString = client!.sessionId!.serverVersion;
      final int majorVersion = int.parse(serverVersionString.split('.').first);
      final userId = session?.userId.toInt();

      final response = await odooClient({
        'model': 'hr.leave.report.calendar',
        'method': 'search_read',
        'args': [
          [
            ['start_datetime', '<=', _formatOdooDateTime(to)],
            ['stop_datetime', '>=', _formatOdooDateTime(from)],
            ['state', '!=', 'cancel'],
          ],
        ],
        'kwargs': {
          'fields': [
            'id',
            'name',
            'state',
            'start_datetime',
            'stop_datetime',
            'display_name',
            if (majorVersion >= 19) 'duration_display',
            if (majorVersion >= 18) 'holiday_status_id',
          ],
          'context': {'uid': userId},
        },
      });

      if (response is! List) return [];

      return response
          .map((e) => LeaveCalendarEvent.fromJson(Map<String, dynamic>.from(e)))
          .toList();
    } catch (e, stackTrace) {
      return [];
    }
  }

  /// Formats a [DateTime] into an Odoo-compatible date-time string.
  static String _formatOdooDateTime(DateTime d) {
    return "${d.year}-${d.month.toString().padLeft(2, '0')}-"
        "${d.day.toString().padLeft(2, '0')} 00:00:00";
  }

  /// Fetches detailed time-off request records, optionally filtered by a [domain].
  static Future<List<ModelTimeOffData>> fetchLeaveTimeOffDetails({
    List<dynamic>? domain,
  }) async {
    try {
      final odooClient = await OdooSessionManager.callKwWithCompany;
      final session = await OdooSessionManager.getCurrentSession();
      final client = await OdooSessionManager.getClient();
      final String serverVersionString = client!.sessionId!.serverVersion;
      final int majorVersion = int.parse(serverVersionString.split('.').first);

      final userId = session?.userId.toInt();

      final result = await odooClient({
        'model': 'hr.leave',
        'method': 'search_read',
        'args': [],
        'kwargs': {
          'domain': domain,
          'fields': [
            'id',
            'name',
            'state',
            'date_from',
            'date_to',
            majorVersion >= 18 ? 'duration_display' : 'number_of_days_display',
            'holiday_status_id',
            'employee_id',
            'department_id',
            'can_approve',
            if (majorVersion == 19) 'can_validate',
            if (majorVersion == 19) 'can_refuse',
            'create_date',
          ],
          'order': 'date_from DESC',
        },
      });

      if (result is! List) {
        return [];
      }

      return result
          .map<ModelTimeOffData>(
            (e) => ModelTimeOffData.fromJson(Map<String, dynamic>.from(e)),
          )
          .toList();
    } catch (_) {
      return [];
    }
  }

  /// Approves a specific leave request.
  static Future<void> actionApprove(int leaveId) async {
    final odooClient = await OdooSessionManager.callKwWithCompany;

    await odooClient({
      'model': 'hr.leave',
      'method': 'action_approve',
      'args': [
        [leaveId],
      ],
      'kwargs': {},
    });
  }

  /// Refuses a specific leave request.
  static Future<void> actionRefuse(int leaveId) async {
    final odooClient = await OdooSessionManager.callKwWithCompany;

    await odooClient({
      'model': 'hr.leave',
      'method': 'action_refuse',
      'args': [
        [leaveId],
      ],
      'kwargs': {},
    });
  }

  /// Validates a specific leave request.
  static Future<void> actionValidate(int leaveId) async {
    final odooClient = await OdooSessionManager.callKwWithCompany;

    await odooClient({
      'model': 'hr.leave',
      'method': 'action_validate',
      'args': [
        [leaveId],
      ],
      'kwargs': {},
    });
  }

  /// Fetches a list of employees for the manager to potentially add time off for.
  static Future<List<Employee>> fetchManagerAddTimeOffEmployees() async {
    try {
      final response = await OdooSessionManager.callKwWithCompany({
        'model': 'hr.employee',
        'method': 'search_read',
        'args': [],
        'kwargs': {
          'domain': [],
          'fields': [
            'id',
            'name',
            'display_name',
            'department_id',
            'image_128',
          ],
        },
      });

      if (response is List) {
        return response
            .map((e) => Employee.fromJson(Map<String, dynamic>.from(e)))
            .toList();
      }

      return [];
    } catch (e) {
      return [];
    }
  }

  /// Fetches available leave types for a specific employee.
  ///
  /// Supports a [query] string for filtering by name.
  static Future<List<ModelTimeOffAddTimeOffType>>
  fetchLeaveTypesByEmployeeInAddTimeOff({
    required int employeeId,
    String query = '',
  }) async {
    try {
      final odooClient = await OdooSessionManager.callKwWithCompany;
      final session = await OdooSessionManager.getCurrentSession();

      final version = session!.odooSession.serverVersion;

      final response = await odooClient({
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
            if (query.trim().isNotEmpty) ['display_name', 'ilike', query],
          ],
          'specification': {
            'display_name': {},
            'allows_negative': {},
            'has_valid_allocation': {},
            'virtual_remaining_leaves': {},

            'requires_allocation': {},
          },
          'context': {'hide_employee_name': 1, 'employee_id': employeeId},
        },
      });

      if (response is Map && response['records'] is List) {
        final records = response['records'] as List;
        return records.map<ModelTimeOffAddTimeOffType>((e) {
          final map = Map<String, dynamic>.from(e);

          return ModelTimeOffAddTimeOffType(
            id: map['id'] ?? 0,
            name: map['display_name'] ?? map['name'] ?? '',
          );
        }).toList();
      }

      return [];
    } catch (e) {
      return [];
    }
  }

  /// Fetches leave allocation records, optionally filtered by [domain].
  static Future<List<ModelAllocationData>>
  fetchManagerLeaveAllocationDetailsView({List<dynamic>? domain}) async {
    try {
      final odooClient = await OdooSessionManager.callKwWithCompany;
      final session = await OdooSessionManager.getCurrentSession();
      final userId = session?.userId.toInt();

      final result = await odooClient({
        'model': 'hr.leave.allocation',
        'method': 'search_read',
        'args': [],
        'kwargs': {'domain': domain ?? [], 'fields': []},
        'context': {'uid': userId},
      });

      if (result is! List) return [];

      return result
          .map<ModelAllocationData>(
            (e) => ModelAllocationData.fromJson(Map<String, dynamic>.from(e)),
          )
          .toList();
    } catch (_) {
      return [];
    }
  }

  /// Approves a specific leave allocation request.
  static Future<void> actionApproveAllocation(int allocationId) async {
    final odooClient = await OdooSessionManager.callKwWithCompany;

    await odooClient({
      'model': 'hr.leave.allocation',
      'method': 'action_approve',
      'args': [
        [allocationId],
      ],
      'kwargs': {},
    });
  }

  /// Refuses a specific leave allocation request.
  static Future<void> actionRefuseAllocation(int allocationId) async {
    final odooClient = await OdooSessionManager.callKwWithCompany;

    await odooClient({
      'model': 'hr.leave.allocation',
      'method': 'action_refuse',
      'args': [
        [allocationId],
      ],
      'kwargs': {},
    });
  }
}
