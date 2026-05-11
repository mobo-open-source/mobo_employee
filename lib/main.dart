import 'package:flutter/material.dart';
import 'package:mobo_employees/core/providers/logout_view_model.dart';
import 'package:mobo_employees/core/services/session_service.dart';
import 'package:mobo_employees/core/theme/theme_provider.dart';
import 'package:mobo_employees/core/theme/themeData.dart';
import 'package:mobo_employees/features/company/providers/company_provider.dart';
import 'package:mobo_employees/features/employee/attendance/provider/attendance_provider.dart';
import 'package:mobo_employees/features/employee/bottom_navigation_bar/bottom_navigation_bar_provider.dart';
import 'package:mobo_employees/features/employee/dashboard/page/dashboard_page.dart';
import 'package:mobo_employees/features/employee/dashboard/provider/dashboard_provider.dart';
import 'package:mobo_employees/features/login/pages/server_setup_screen.dart';
import 'package:mobo_employees/features/login/providers/login_provider.dart';
import 'package:mobo_employees/features/manager/manager_approvals/providers/manager_approvals_provider.dart';
import 'package:mobo_employees/features/manager/manager_attendance/provider/manager_attendance_provider.dart';
import 'package:mobo_employees/features/manager/manager_bottom_nav_bar/manager_bottom_navbar_provider.dart';
import 'package:mobo_employees/features/manager/manager_dashboard/provider/manager_dashboard_provider.dart';
import 'package:mobo_employees/features/manager/manager_employees/provider/manager_employees_provider.dart';
import 'package:mobo_employees/features/profile/providers/profile_provider.dart';
import 'package:mobo_employees/features/roles_check/role_check_provider.dart';
import 'package:mobo_employees/features/settings/providers/settings_provider.dart';
import 'package:mobo_employees/features/splashVideo/splash_video.dart';
import 'package:mobo_employees/features/user_type_role_check/user_type_role_check_provider.dart';
import 'package:provider/provider.dart';

import 'core/const/keys/global_keys.dart';
import 'features/employee/leave/provider/leave_page_provider.dart';
import 'features/review/services/review_service.dart';

void main() {
  runApp(
    MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => ThemeProvider()),
        ChangeNotifierProvider(create: (_) => LoginProvider()),
        ChangeNotifierProvider(create: (_) => UserTypeRoleCheckProvider()),
        ChangeNotifierProvider(create: (_) => RoleProvider()),
        ChangeNotifierProvider(create: (_) => BottomNavProvider()),
        ChangeNotifierProvider(create: (_) => ManagerBottomNavbarProvider()),

        ChangeNotifierProvider(
          create: (_) {
            final provider = DashboardProvider();
            provider.init();
            return provider;
          },
        ),
        ChangeNotifierProvider(
          create: (_) {
            final provider = ManagerDashboardProvider();
            return provider;
          },
        ),
        ChangeNotifierProvider(create: (_) => AttendanceProvider()),
        ChangeNotifierProvider(create: (_) => LeavePageProvider()),
        ChangeNotifierProvider(create: (_) => ManagerEmployeesProvider()),
        ChangeNotifierProvider(create: (_) => ManagerAttendanceProvider()),
        ChangeNotifierProvider(create: (_) => ManagerApprovalsProvider()),
        ChangeNotifierProvider(create: (_) => SettingsProvider()),
        ChangeNotifierProvider(create: (_) => LogoutViewModel()),
        ChangeNotifierProvider(create: (_) => ProfileProvider()),
        ChangeNotifierProvider<SessionService>.value(
          value: SessionService.instance,
        ),
        ChangeNotifierProvider(
          create: (_) {
            final p = CompanyProvider();
            /// Kick off initial load from server; will show loading in selector
            p.initialize();
            return p;
          },
        ),
      ],
      child:
          const MyApp(),
    ),
  );
}

class MyApp extends StatefulWidget {
  const MyApp({super.key});

  @override
  State<MyApp> createState() => _MyAppState();
}

class _MyAppState extends State<MyApp> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      Future.delayed(const Duration(seconds: 2), () {
        ReviewService().trackAppOpen();
      });
    });
  }

  @override
  Widget build(BuildContext context) {
    return Consumer<ThemeProvider>(
      builder: (context, provider, child) {
        return MaterialApp(
          themeMode: provider.themeMode,
          darkTheme: AppTheme.darkTheme,
          theme: AppTheme.lightTheme,
          debugShowCheckedModeBanner: false,
          navigatorKey: navigatorKey,
          scaffoldMessengerKey: scaffoldMessengerKey,
          home:
              const SplashScreen(),
             routes: {
            '/server_setup': (_) => const ServerSetupScreen(),
            '/home': (_) => const DashboardPage(),
          },
        );
      },
    );
  }
}


