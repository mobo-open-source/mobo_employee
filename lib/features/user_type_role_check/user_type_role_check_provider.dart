import 'package:flutter/material.dart';
import 'package:mobo_employees/core/services/odoo_session_manager.dart';

class UserTypeRoleCheckProvider extends ChangeNotifier {
  List<int> _groupIds = [];

  List<int> get groupIds => _groupIds;

  bool get isUser => _groupIds.contains(1);
  bool get isPortal => _groupIds.contains(10);
  bool get isPublic => _groupIds.contains(11);
  bool get isAdmin => _groupIds.contains(4);

  String get role {
    if (isAdmin) return "ADMIN";
    if (isUser) return "USER";
    if (isPortal) return "PORTAL";
    if (isPublic) return "PUBLIC";
    return "UNKNOWN";
  }

  Future<void> fetchAndSetUserRole() async {
    try {
      final client = await OdooSessionManager.getClientEnsured();
      final String versionString = client!.sessionId!.serverVersion;
      final int majorVersion = int.parse(versionString.split('.').first);

      final sessionInfo = await client.callRPC(
        '/web/session/get_session_info',
        'call',
        {},
      );
      final userId = sessionInfo['uid'];

      List<int> fetchedGroups = [];

      ///  VERSION BASED HANDLING

      if (majorVersion >= 19) {
        fetchedGroups.clear();

        if (sessionInfo['is_admin'] == true) {
          fetchedGroups.add(4);
        } else if (sessionInfo['is_internal_user'] == true) {
          fetchedGroups.add(1);
        } else if (sessionInfo['is_public'] == true) {
          fetchedGroups.add(11);
        } else {
          /// fallback → treat as portal
          fetchedGroups.add(10);
        }
      } else if (majorVersion == 18) {
        final result = await client.callKw({
          'model': 'res.users',
          'method': 'web_read',
          'args': [
            [userId],
          ],
          'kwargs': {
            'specification': {'sel_groups_1_10_11': {}},
          },
        });

        fetchedGroups.clear();

        if (result is List && result.isNotEmpty) {
          final groupValue = result[0]['sel_groups_1_10_11'];

          if (groupValue == 1) {
            fetchedGroups.add(1);
          } else if (groupValue == 10) {
            fetchedGroups.add(10);
          } else if (groupValue == 11) {
            fetchedGroups.add(11);
          }
        }
      } else if (majorVersion == 17) {
        final result = await client.callKw({
          'model': 'res.users',
          'method': 'web_read',
          'args': [
            [userId],
          ],
          'kwargs': {
            'specification': {'sel_groups_1_10_11': {}},
          },
        });

        fetchedGroups.clear();

        if (result is List && result.isNotEmpty) {
          final groupValue = result[0]['sel_groups_1_10_11'];

          if (groupValue == 1) {
            fetchedGroups.add(1);
          } else if (groupValue == 10) {
            fetchedGroups.add(10);
          } else if (groupValue == 11) {
            fetchedGroups.add(11);
          }
        }
      }

      ///  Assign and notify
      _groupIds = fetchedGroups;

      if (isPortal) {}

      if (isPublic) {}
      notifyListeners();
    } catch (e) {
      /// Avoid trapping the app on a loading screen when role lookup fails.
      _groupIds = [1];
      notifyListeners();
    }
  }

  Future<void> clearOnLogout() async {
    _groupIds = [];
    notifyListeners();
  }
}
