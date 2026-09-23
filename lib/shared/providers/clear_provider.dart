import 'package:flutter/material.dart';
import 'package:mobo_employees/features/employee/attendance/provider/attendance_provider.dart';
import 'package:mobo_employees/features/employee/bottom_navigation_bar/bottom_navigation_bar_provider.dart';
import 'package:mobo_employees/features/employee/dashboard/provider/dashboard_provider.dart';
import 'package:mobo_employees/features/employee/leave/provider/leave_page_provider.dart';
import 'package:mobo_employees/features/manager/manager_approvals/providers/manager_approvals_provider.dart';
import 'package:mobo_employees/features/manager/manager_attendance/provider/manager_attendance_provider.dart';
import 'package:mobo_employees/features/manager/manager_bottom_nav_bar/manager_bottom_navbar_provider.dart';
import 'package:mobo_employees/features/manager/manager_dashboard/provider/manager_dashboard_provider.dart';
import 'package:mobo_employees/features/manager/manager_employees/provider/manager_employees_provider.dart';
import 'package:mobo_employees/features/roles_check/role_check_provider.dart';
import 'package:mobo_employees/features/user_type_role_check/user_type_role_check_provider.dart';
import 'package:mobo_employees/features/profile/providers/profile_provider.dart';

import 'package:provider/provider.dart';

class ClearProviders {
  static Future<void> clearAllProviders(BuildContext context) async {
    context.read<BottomNavProvider>().clearOnLogout();
    context.read<ManagerBottomNavbarProvider>().clearOnLogout();
    await context.read<DashboardProvider>().clearOnLogout();
    context.read<AttendanceProvider>().clearOnLogout();
    context.read<LeavePageProvider>().clearOnLogout();
    context.read<RoleProvider>().clearOnLogout();
    await context.read<ManagerDashboardProvider>().clearOnManagerLogout();
    context.read<ManagerAttendanceProvider>().clearOnManagerLogout();
    context.read<ManagerApprovalsProvider>().clearOnManagerLogout();
    context.read<ManagerEmployeesProvider>().clearOnManagerLogout();
    await context.read<UserTypeRoleCheckProvider>().clearOnLogout();

    /// Drops ProfileProvider's per-account state (cached data, queued
    /// edits, and server probes) so it isn't read back against a
    /// different account. See ProfileProvider.resetState().
    context.read<ProfileProvider>().resetState();
  }
}
