import 'package:mobo_employees/core/services/odoo_session_manager.dart';
import 'package:mobo_employees/features/roles_check/role_check_provider.dart';

class UserRoleService {

  ///fetching the user Role from odoo
  static Future<UserRole> getUserRole() async {
    try {
      final session = await OdooSessionManager.getCurrentSession();

      if (session?.userId == null) {
        return UserRole.officer;
      }

      final uid = session!.userId;
      final client = await OdooSessionManager.getClient();
      final String serverVersionString = client!.sessionId!.serverVersion;
      final int majorVersion = int.parse(serverVersionString.split('.').first);

      if (majorVersion >= 18) {
        final isHrManager = await OdooSessionManager.callKwWithCompany({
          'model': 'res.users',
          'method': 'has_group',
          'args': [uid, 'hr.group_hr_manager'],
          'kwargs': {},
        });

        final isHrOfficer = await OdooSessionManager.callKwWithCompany({
          'model': 'res.users',
          'method': 'has_group',
          'args': [uid, 'hr.group_hr_user'],
          'kwargs': {},
        });

        if (isHrManager == true || isHrOfficer == true) {
          return UserRole.administrator;
        }

        return UserRole.officer;
      } else {
        final isHrManager = await OdooSessionManager.callKwWithCompany({
          'model': 'res.users',
          'method': 'has_group',
          'args': ['hr.group_hr_manager'],
          'kwargs': {},
        });

        final isHrOfficer = await OdooSessionManager.callKwWithCompany({
          'model': 'res.users',
          'method': 'has_group',
          'args': ['hr.group_hr_user'],
          'kwargs': {},
        });
        if (isHrManager || isHrOfficer) {
          return UserRole.administrator;
        }
        return UserRole.officer;
      }
    } catch (e, stack) {
      return UserRole.officer;
    }
  }
}
