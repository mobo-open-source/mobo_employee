import 'dart:convert';

import 'package:mobo_employees/core/services/connectivity_service.dart';
import 'package:mobo_employees/core/services/odoo_session_manager.dart';
import 'package:mobo_employees/features/manager/manager_approvals/models/model_allocation_data.dart';
import 'package:mobo_employees/features/manager/manager_approvals/models/model_leave_calendar_event.dart';
import 'package:mobo_employees/features/manager/manager_approvals/models/model_time_off_add_employees.dart';
import 'package:mobo_employees/features/manager/manager_approvals/models/model_time_off_add_time_off_type.dart';
import 'package:mobo_employees/features/manager/manager_approvals/models/model_timeoff_data.dart';
import 'package:mobo_employees/shared/services/time_off_type_service.dart';

/// Service class for managing calendar and leave-related operations for managers.
///
/// This service provides methods to fetch leave summaries, calendar events,
/// allocation details, and perform approval actions through the Odoo backend.
class ManagerCalendarService {
  /// Whether [userId] holds the HR Officer or HR Manager group. Such users
  /// are legitimate approvers company-wide under Odoo's own permission
  /// model — not just for their literal direct reports — so approval
  /// listings below skip the direct-reports domain restriction for them (and
  /// the manager dashboard's leave cards follow the same rule).
  static Future<bool> isHrManagerOrOfficer(int userId) async {
    try {
      final isHrManager = await OdooSessionManager.callKwWithCompany({
        'model': 'res.users',
        'method': 'has_group',
        'args': [
          [userId],
          'hr.group_hr_manager',
        ],
        'kwargs': {},
      });
      final isHrOfficer = await OdooSessionManager.callKwWithCompany({
        'model': 'res.users',
        'method': 'has_group',
        'args': [
          [userId],
          'hr.group_hr_user',
        ],
        'kwargs': {},
      });
      return isHrManager == true || isHrOfficer == true;
    } catch (e) {
      if (ConnectivityService.isConnectivityError(e)) rethrow;
      return false;
    }
  }

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

  /// Fetches base64-encoded profile images for several employees in ONE
  /// request, keyed by employee id, instead of one RPC per row.
  static Future<Map<int, String?>> fetchEmployeeUserProfileImages(
    List<int> userIds,
  ) async {
    if (userIds.isEmpty) return {};
    try {
      final odooClient = await OdooSessionManager.callKwWithCompany;

      final response = await odooClient({
        'model': 'hr.employee',
        'method': 'search_read',
        'args': [],
        'kwargs': {
          'domain': [
            ['id', 'in', userIds],
          ],
          'fields': ['id', 'image_128'],
        },
      });

      final result = <int, String?>{};
      if (response is List) {
        for (final row in response) {
          final id = row['id'];
          if (id is int) {
            result[id] = row['image_128'] as String?;
          }
        }
      }
      return result;
    } catch (e) {
      return {};
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
      final majorVersion = await OdooSessionManager.getServerMajorVersion();
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
            /// Odoo 20 replaced hr.leave.type with hr.work.entry.type
            majorVersion >= 20 ? 'work_entry_type_id' : 'holiday_status_id',
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

      /// Odoo 20 dropped start_datetime/stop_datetime from the calendar
      /// report; filter and read the stored request dates instead.
      final response = await odooClient({
        'model': 'hr.leave.report.calendar',
        'method': 'search_read',
        'args': [
          [
            if (majorVersion >= 20) ...[
              ['request_date_from', '<=', _formatOdooDate(to)],
              ['request_date_to', '>=', _formatOdooDate(from)],
            ] else ...[
              ['start_datetime', '<=', _formatOdooDateTime(to)],
              ['stop_datetime', '>=', _formatOdooDateTime(from)],
            ],
            ['state', '!=', 'cancel'],
          ],
        ],
        'kwargs': {
          'fields': [
            'id',
            'name',
            'state',
            /// Plain dates: Odoo 20's request_date_hour_from/to are
            /// timezone-shifted and end at the *next* midnight, which put
            /// full-day leaves one day off in the calendar.
            if (majorVersion >= 20) ...[
              'request_date_from',
              'request_date_to',
            ] else ...[
              'start_datetime',
              'stop_datetime',
            ],
            'display_name',
            if (majorVersion >= 19) 'duration_display',
            /// The report's time off type (holiday_status_id on 18/19,
            /// work_entry_type_id on 20) is readable by Time Off Officers
            /// only: asking for it made the whole read fail with an
            /// AccessError for any other approver, leaving the calendar
            /// empty. The event reads the type from display_name instead.
          ],
          'context': {'uid': userId},
        },
      });

      if (response is! List) return [];

      return response
          .map((e) => LeaveCalendarEvent.fromJson(Map<String, dynamic>.from(e)))
          .toList();
    } catch (e, stackTrace) {
      if (ConnectivityService.isConnectivityError(e)) rethrow;
      return [];
    }
  }

  /// Formats a [DateTime] into an Odoo-compatible date string.
  static String _formatOdooDate(DateTime d) {
    return "${d.year}-${d.month.toString().padLeft(2, '0')}-"
        "${d.day.toString().padLeft(2, '0')}";
  }

  /// Formats a [DateTime] into an Odoo-compatible date-time string.
  static String _formatOdooDateTime(DateTime d) {
    return "${d.year}-${d.month.toString().padLeft(2, '0')}-"
        "${d.day.toString().padLeft(2, '0')} 00:00:00";
  }

  /// Fetches detailed time-off request records, optionally filtered by a [domain].
  ///
  /// [restrictToTeam] scopes plain line managers to their direct reports for
  /// the approvals queue. Pass `false` for a user's own requests ("My Time
  /// Off"): those are already limited by [domain], and the team scope would
  /// hide them unless the user happened to be their own manager.
  static Future<List<ModelTimeOffData>> fetchLeaveTimeOffDetails({
    List<dynamic>? domain,
    bool restrictToTeam = true,
  }) async {
    try {
      final odooClient = await OdooSessionManager.callKwWithCompany;
      final session = await OdooSessionManager.getCurrentSession();
      final client = await OdooSessionManager.getClient();
      final String serverVersionString = client!.sessionId!.serverVersion;
      final int majorVersion = int.parse(serverVersionString.split('.').first);

      final userId = session?.userId.toInt();

      /// A plain line manager must only ever see their own direct reports'
      /// leave requests here. An HR Officer/Manager is a legitimate
      /// company-wide approver under Odoo's own permission model, so the
      /// restriction is skipped for them — otherwise a request whose
      /// employee doesn't have this HR user set as their literal reporting
      /// manager (parent_id) would wrongly disappear from their queue.
      final passedDomain = domain ?? [];
      final canSeeCompanyWide =
          !restrictToTeam ||
          (userId != null && await isHrManagerOrOfficer(userId));
      final scopedDomain = (userId == null || canSeeCompanyWide)
          ? passedDomain
          : (passedDomain.isEmpty
                ? [
                    ['employee_id.parent_id.user_id', '=', userId],
                  ]
                : [
                    '&',
                    ['employee_id.parent_id.user_id', '=', userId],
                    ...passedDomain,
                  ]);

      final result = await odooClient({
        'model': 'hr.leave',
        'method': 'search_read',
        'args': [],
        'kwargs': {
          'domain': scopedDomain,
          'fields': [
            'id',
            'name',
            'state',
            'date_from',
            'date_to',
            majorVersion >= 18 ? 'duration_display' : 'number_of_days_display',
            /// Odoo 20 replaced hr.leave.type with hr.work.entry.type
            majorVersion >= 20 ? 'work_entry_type_id' : 'holiday_status_id',
            'employee_id',
            'department_id',
            'can_approve',
            if (majorVersion >= 19) 'can_validate',
            if (majorVersion >= 19) 'can_refuse',
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
    } catch (e) {
      if (ConnectivityService.isConnectivityError(e)) rethrow;
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
    final majorVersion = await OdooSessionManager.getServerMajorVersion();

    await odooClient({
      'model': 'hr.leave',
      /// Odoo 20 dropped action_validate; action_approve does both steps
      'method': majorVersion >= 20 ? 'action_approve' : 'action_validate',
      'args': [
        [leaveId],
      ],
      'kwargs': {},
    });
  }

  /// Fetches a list of employees for the manager to potentially add time off for.
  ///
  /// [domain] narrows the list further (e.g. to the employees an attendance
  /// officer manages); Odoo's record rules always apply on top.
  static Future<List<Employee>> fetchManagerAddTimeOffEmployees({
    List<dynamic> domain = const [],
  }) async {
    try {
      final response = await OdooSessionManager.callKwWithCompany({
        'model': 'hr.employee',
        'method': 'search_read',
        'args': [],
        'kwargs': {
          'domain': domain,
          'fields': [
            'id',
            'name',
            'display_name',
            'department_id',
            'avatar_128',
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

      /// Odoo 20 replaced hr.leave.type with hr.work.entry.type
      if (await OdooSessionManager.getServerMajorVersion() >= 20) {
        final records = await TimeOffTypeService.fetchSelectableTypes(
          employeeId: employeeId,
          query: query,
        );
        return records
            .map(
              (map) => ModelTimeOffAddTimeOffType(
                id: map['id'] ?? 0,
                name: map['display_name'] ?? '',
              ),
            )
            .toList();
      }

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

  /// Allocation states still awaiting approval: Odoo's "To Approve" and
  /// "Second Approval".
  static const List<String> pendingAllocationStates = ['confirm', 'validate1'];

  /// [domain] narrowed to the allocations [userId] approves.
  ///
  /// A plain line manager must only ever see their own direct reports'
  /// allocations. An HR Officer/Manager is a legitimate company-wide approver
  /// under Odoo's own permission model, so the restriction is skipped for
  /// them (see [fetchLeaveTimeOffDetails]). The one scope behind the
  /// Allocation tab and the Calendar tab's "Pending" card, so the two agree.
  static Future<List<dynamic>> _allocationDomain(
    List<dynamic> domain,
    int? userId,
  ) async {
    final canSeeCompanyWide =
        userId != null && await isHrManagerOrOfficer(userId);
    if (userId == null || canSeeCompanyWide) return domain;
    return domain.isEmpty
        ? [
            ['employee_id.parent_id.user_id', '=', userId],
          ]
        : [
            '&',
            ['employee_id.parent_id.user_id', '=', userId],
            ...domain,
          ];
  }

  /// Number of allocation requests awaiting approval in the Allocation tab:
  /// the ones the manager can act on, not just their own.
  ///
  /// Odoo's own dashboard figure (`get_allocations_number`) counts only the
  /// current employee's requests, which is why the "Pending" card read 0
  /// while the tab listed requests from the team.
  static Future<int> fetchPendingAllocationCount() async {
    final session = await OdooSessionManager.getCurrentSession();
    final domain = await _allocationDomain([
      ['state', 'in', pendingAllocationStates],
    ], session?.userId.toInt());

    final count = await OdooSessionManager.callKwWithCompany({
      'model': 'hr.leave.allocation',
      'method': 'search_count',
      'args': [domain],
      'kwargs': {},
    });
    return count is int ? count : 0;
  }

  /// Fetches leave allocation records, optionally filtered by [domain].
  static Future<List<ModelAllocationData>>
  fetchManagerLeaveAllocationDetailsView({List<dynamic>? domain}) async {
    try {
      final odooClient = await OdooSessionManager.callKwWithCompany;
      final session = await OdooSessionManager.getCurrentSession();
      final userId = session?.userId.toInt();

      final scopedDomain = await _allocationDomain(domain ?? [], userId);

      final result = await odooClient({
        'model': 'hr.leave.allocation',
        'method': 'search_read',
        'args': [],
        'kwargs': {'domain': scopedDomain, 'fields': []},
        'context': {'uid': userId},
      });

      if (result is! List) return [];

      return result
          .map<ModelAllocationData>(
            (e) => ModelAllocationData.fromJson(Map<String, dynamic>.from(e)),
          )
          .toList();
    } catch (e) {
      if (ConnectivityService.isConnectivityError(e)) rethrow;
      return [];
    }
  }

  /// Time off types an allocation can be created for — those Odoo's
  /// allocation form offers a Time Off Officer: types requiring allocation.
  static Future<List<ModelTimeOffAddTimeOffType>>
  fetchAllocatableLeaveTypes() async {
    try {
      final majorVersion = await OdooSessionManager.getServerMajorVersion();

      /// Odoo 20 replaced hr.leave.type with hr.work.entry.type
      if (majorVersion >= 20) {
        final response = await OdooSessionManager.callKwWithCompany({
          'model': 'hr.work.entry.type',
          'method': 'search_read',
          'args': [],
          'kwargs': {
            'domain': [
              ['requires_allocation', '=', true],
              ['time_off_selectable', '=', true],
            ],
            'fields': ['id', 'display_name'],
            'order': 'sequence ASC, id ASC',
          },
        });
        if (response is! List) return [];
        return response
            .map(
              (e) => ModelTimeOffAddTimeOffType(
                id: e['id'] ?? 0,
                name: e['display_name'] ?? '',
              ),
            )
            .toList();
      }

      /// `requires_allocation` is Selection('yes'/'no') up to 18 and boolean
      /// afterwards, so filter client-side to support both.
      final response = await OdooSessionManager.callKwWithCompany({
        'model': 'hr.leave.type',
        'method': 'search_read',
        'args': [],
        'kwargs': {
          'domain': [],
          'fields': ['id', 'display_name', 'requires_allocation'],
          'order': 'sequence ASC, id ASC',
        },
      });
      if (response is! List) return [];
      return response
          .where(
            (e) =>
                e['requires_allocation'] == true ||
                e['requires_allocation'] == 'yes',
          )
          .map(
            (e) => ModelTimeOffAddTimeOffType(
              id: e['id'] ?? 0,
              name: e['display_name'] ?? '',
            ),
          )
          .toList();
    } catch (_) {
      return [];
    }
  }

  /// Creates an `hr.leave.allocation`, as Odoo's Allocations > New form does
  /// for a Time Off Officer. Odoo decides the resulting state (To Approve,
  /// or Approved for types needing no validation) and enforces its
  /// constraints, raising the message the caller should show.
  static Future<int> createAllocation({
    required int employeeId,
    required int leaveTypeId,
    required double numberOfDays,
    required DateTime dateFrom,
    DateTime? dateTo,
    String description = '',
  }) async {
    final majorVersion = await OdooSessionManager.getServerMajorVersion();
    final values = <String, dynamic>{
      'employee_id': employeeId,

      /// On 17, `employee_id` is computed from `employee_ids`, which
      /// otherwise defaults to the *current user's* employee.
      if (majorVersion < 18) 'holiday_type': 'employee',
      if (majorVersion < 18)
        'employee_ids': [
          [
            6,
            0,
            [employeeId],
          ],
        ],
      TimeOffTypeService.typeField(majorVersion): leaveTypeId,
      'number_of_days': numberOfDays,
      'date_from': _formatOdooDate(dateFrom),
      'date_to': dateTo == null ? false : _formatOdooDate(dateTo),
      if (description.trim().isNotEmpty) 'name': description.trim(),
    };

    final result = await OdooSessionManager.callKwWithCompany({
      'model': 'hr.leave.allocation',
      'method': 'create',
      'args': [values],
      'kwargs': {},
    });
    return result as int;
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
