import 'package:flutter/material.dart';
import 'package:mobo_employees/features/employee/attendance/provider/attendance_provider.dart';
import 'package:mobo_employees/features/employee/bottom_navigation_bar/bottom_navigation_bar_provider.dart';
import 'package:mobo_employees/features/employee/dashboard/provider/dashboard_provider.dart';
import 'package:mobo_employees/features/employee/leave/provider/leave_page_provider.dart';
import 'package:mobo_employees/features/manager/manager_approvals/providers/manager_approvals_provider.dart';
import 'package:mobo_employees/features/manager/manager_attendance/provider/manager_attendance_provider.dart';
import 'package:mobo_employees/features/manager/manager_dashboard/provider/manager_dashboard_provider.dart';
import 'package:mobo_employees/features/manager/manager_employees/provider/manager_employees_provider.dart';
import 'package:mobo_employees/features/roles_check/role_check_provider.dart';
import 'package:mobo_employees/features/user_type_role_check/user_type_role_check_provider.dart';

import 'package:provider/provider.dart';

class ClearProviders {
  static Future<void> clearAllProviders(BuildContext context) async {
      context.read<BottomNavProvider>().clearOnLogout();
    context.read<DashboardProvider>().clearOnLogout();
    context.read<AttendanceProvider>().clearOnLogout();
    context.read<LeavePageProvider>().clearOnLogout();
    context.read<RoleProvider>().clearOnLogout();
    context.read<ManagerDashboardProvider>().clearOnManagerLogout();
    context.read<ManagerAttendanceProvider>().clearOnManagerLogout();
    context.read<ManagerApprovalsProvider>().clearOnManagerLogout();
    context.read<ManagerEmployeesProvider>().clearOnManagerLogout();
    context.read<UserTypeRoleCheckProvider>().clearOnLogout();
  }
}
