import 'package:flutter/widgets.dart';
import 'package:mobo_employees/features/roles_check/role_check_provider.dart';
import 'package:mobo_employees/shared/providers/clear_provider.dart';
import 'package:provider/provider.dart';

/// Reads the user's role again and, when an administrator changed it in Odoo
/// since it was last read, drops what the manager view holds so it's read
/// again with the new access. AppEntry, which watches [RoleProvider], then
/// shows the employee or manager view the new role calls for.
Future<void> refreshUserRole(BuildContext context) async {
  final changed = await context.read<RoleProvider>().refreshRole();
  if (changed && context.mounted) await ClearProviders.clearRoleViews(context);
}
