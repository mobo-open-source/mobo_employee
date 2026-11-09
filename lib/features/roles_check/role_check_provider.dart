import 'package:flutter/cupertino.dart';
import 'package:mobo_employees/features/roles_check/user_role_service.dart';

enum UserRole { officer, administrator }

class RoleProvider extends ChangeNotifier {
  UserRole? _role;
  UserRole? get role => _role;

  bool _isRefreshing = false;

  Future<void> loadRole() async {
    _role = await UserRoleService.getUserRole() ?? UserRole.officer;
    notifyListeners();
  }

  /// Reads the role again: an administrator may change this user's groups
  /// in Odoo while the app is open. Keeps the current role when the server
  /// can't answer. Returns whether the role changed.
  Future<bool> refreshRole() async {
    if (_role == null || _isRefreshing) return false;
    _isRefreshing = true;
    try {
      final role = await UserRoleService.getUserRole();

      // Logged out meanwhile ([_role] cleared): don't bring a role back.
      if (role == null || _role == null || role == _role) return false;
      _role = role;
      notifyListeners();
      return true;
    } finally {
      _isRefreshing = false;
    }
  }

  bool get isAdmin => _role == UserRole.administrator;
  bool get isOfficer => _role == UserRole.officer;

  void clearOnLogout() {
    _role = null;
    notifyListeners();
  }
}
