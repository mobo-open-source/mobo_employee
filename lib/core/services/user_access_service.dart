import 'package:mobo_employees/core/services/connectivity_service.dart';
import 'package:mobo_employees/core/services/odoo_session_manager.dart';

/// Checks the logged-in user's Odoo security groups, so the app offers the
/// same records and actions Odoo's own UI offers that user.
class UserAccessService {
  /// Attendance "Administrator": full access to every attendance.
  static const String attendanceAdmin =
      'hr_attendance.group_hr_attendance_manager';

  /// Odoo 20+ "Officer: Manage all attendances". Doesn't exist on 17/18,
  /// where only [attendanceAdmin] sees everyone.
  static const String attendanceAllOfficer =
      'hr_attendance.group_hr_attendance_user';

  /// Attendance "Officer": may create/edit attendances of the employees
  /// they're the attendance manager of.
  static const String attendanceOfficer =
      'hr_attendance.group_hr_attendance_officer';

  /// Odoo 20+ "Self Attendance Edit": may create and edit their own
  /// attendances. Doesn't exist on 17/18.
  static const String attendanceOwn = 'hr_attendance.group_hr_attendance_own';

  /// Time Off "Officer: Manage all requests": may create allocations.
  static const String timeOffOfficer = 'hr_holidays.group_hr_holidays_user';

  /// Whether the current user belongs to [groupXmlId]. Returns `false` when
  /// there is no session or the group doesn't exist on this Odoo version.
  /// Rethrows when the server can't be reached, so a dropped connection
  /// isn't mistaken for "no access" and cached as such by the caller.
  static Future<bool> hasGroup(String groupXmlId) async {
    try {
      final session = await OdooSessionManager.getCurrentSession();
      final uid = session?.userId;
      if (uid == null) return false;
      final result = await OdooSessionManager.callKwWithCompany({
        'model': 'res.users',
        'method': 'has_group',
        'args': [
          [uid],
          groupXmlId,
        ],
        'kwargs': {},
      });
      return result == true;
    } catch (e) {
      if (ConnectivityService.isConnectivityError(e)) rethrow;
      return false;
    }
  }

  /// Whether Odoo's record rules let the current user see every employee's
  /// attendance (rather than only the employees they manage).
  static Future<bool> canSeeAllAttendances() async {
    return await hasGroup(attendanceAdmin) ||
        await hasGroup(attendanceAllOfficer);
  }

  /// The `hr.employee` domain of the employees Odoo's record rules let the
  /// current user create attendances for, or null when there are none:
  /// everyone ([canSeeAllAttendances]), the employees whose Attendance
  /// manager they are ([attendanceOfficer]), and themselves
  /// ([attendanceOwn]).
  static Future<List<dynamic>?> attendanceCreateDomain() async {
    if (await canSeeAllAttendances()) return const [];
    final session = await OdooSessionManager.getCurrentSession();
    final uid = session?.userId;
    if (uid == null) return null;
    final allowed = <List<dynamic>>[
      if (await hasGroup(attendanceOfficer))
        ['attendance_manager_id', '=', uid],
      if (await hasGroup(attendanceOwn)) ['user_id', '=', uid],
    ];
    if (allowed.isEmpty) return null;
    return [for (var i = 1; i < allowed.length; i++) '|', ...allowed];
  }
}
