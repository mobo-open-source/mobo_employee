import 'package:flutter/cupertino.dart';
import 'package:mobo_employees/features/roles_check/user_role_service.dart';

enum UserRole { officer, administrator }

class RoleProvider extends ChangeNotifier {
  UserRole? _role;
  UserRole? get role => _role;

  Future<void> loadRole() async {
    _role = await UserRoleService.getUserRole();
    notifyListeners();
  }

  bool get isAdmin => _role == UserRole.administrator;
  bool get isOfficer => _role == UserRole.officer;

  void clearOnLogout() {
    _role = null;
    notifyListeners();
  }
}
