import 'package:flutter/material.dart';
import 'package:mobo_employees/core/routing/page_transition.dart';
import 'package:mobo_employees/core/services/biometric_context_service.dart';
import 'package:mobo_employees/core/services/connectivity_service.dart';
import 'package:mobo_employees/core/services/session_service.dart';
import 'package:mobo_employees/features/employee/bottom_navigation_bar/bottom_navigation_bar_page.dart';
import 'package:mobo_employees/features/login/pages/app_lock_screen.dart';
import 'package:mobo_employees/features/login/pages/server_setup_screen.dart';
import 'package:mobo_employees/features/manager/manager_bottom_nav_bar/manager_bottom_navbar_page.dart';
import 'package:mobo_employees/features/module_check/module_check_dialog.dart';
import 'package:mobo_employees/features/roles_check/role_check_provider.dart';
import 'package:mobo_employees/features/user_type_role_check/user_type_role_check_provider.dart';
import 'package:mobo_employees/features/user_type_role_check/widget_show_role_type_dialog.dart';
import 'package:mobo_employees/shared/widgets/loaders/loading_indicator.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:mobo_employees/core/services/odoo_session_manager.dart';
import 'package:mobo_employees/features/get_started_screen/get_started_carousal.dart';
import '../features/company/providers/company_provider.dart';
import '../features/profile/providers/profile_provider.dart';
import '../shared/providers/clear_provider.dart';

class AppEntry extends StatefulWidget {
  final bool skipBiometric;

  const AppEntry({super.key, this.skipBiometric = false});

  @override
  State<AppEntry> createState() => _AppEntryState();
}

class _AppEntryState extends State<AppEntry> {
  late Future<Map<String, dynamic>> _initFuture;
  bool _roleDialogShown = false;

  @override
  void initState() {
    super.initState();
    /// Start monitoring connectivity centrallya
    ConnectivityService.instance.startMonitoring();
    _initFuture = _checkAuthStatus();

    WidgetsBinding.instance.addPostFrameCallback((_) {
      ClearProviders.clearAllProviders(context);
    });
  }

  Future<Map<String, dynamic>> _checkAuthStatus() async {
    await SessionService.instance.initialize();
    final prefs = await SharedPreferences.getInstance();
    final isLoggedInPref = prefs.getBool('isLoggedIn') ?? false;

    bool sessionValid = false;
    if (isLoggedInPref) {
      sessionValid = await OdooSessionManager.isSessionValid();
    }

    final isLoggedIn = isLoggedInPref && sessionValid;
    final biometricEnabled = prefs.getBool('biometric_enabled') ?? false;
    final hasSeenGetStarted = prefs.getBool('hasSeenGetStarted') ?? false;

    if (isLoggedIn) {
      sessionValid = await OdooSessionManager.isSessionValid();
      if (!sessionValid) {
      } else {
        /// Extra safeguard: ensure we can actually authenticate a client.
        /// If this fails due to temporary connectivity or server issues, DO NOT logout.
        /// Let the app proceed so the user can retry inside the app.
        try {
          final client = await OdooSessionManager.getClientEnsured();
          final sessionInfo = await client.callRPC(
            '/web/session/get_session_info',
            'call',
            {},
          );
          /// company_id is usually in: sessionInfo['user_companies']['current_company']
          final currentCompany = sessionInfo;
        } catch (e) {
          /// Intentionally do not clear session here.
        }
      }
    }

    /// If logged in and session is valid, check if Inventory (stock) module is installed
    bool inventoryInstalled = false; /// Force true for now
    List<String> missingModule = [];
    if (isLoggedIn && sessionValid) {
      try {
        final client = await OdooSessionManager.getClientEnsured();
        final sessionInfo = await client.callRPC(
          '/web/session/get_session_info',
          'call',
          {},
        );

        final currentCompanyId =
            sessionInfo['user_companies']?['current_company'];

        if (currentCompanyId == null) {
          inventoryInstalled = true;
        } else {
          final requiredModules = [
            'hr',
            'hr_attendance',
            'hr_holidays',
          ];

          final modules = await client.callKw({
            'model': 'ir.module.module',
            'method': 'search_read',
            'args': [
              [
                ['name', 'in', requiredModules],
                ['state', '=', 'installed'],
              ],
            ],
            'kwargs': {
              'fields': ['name'],
            },
          });

          final installedModules = (modules as List)
              .map((e) => e['name'] as String)
              .toList();

          missingModule = requiredModules
              .where((module) => !installedModules.contains(module))
              .toList();
          inventoryInstalled = installedModules.length == 3;
          await context.read<UserTypeRoleCheckProvider>().clearOnLogout();
          final userRoleProvider = context.read<UserTypeRoleCheckProvider>();
          await userRoleProvider.fetchAndSetUserRole();
          if (inventoryInstalled &&
              !userRoleProvider.isPortal &&
              !userRoleProvider.isPublic) {
            try {
              final sessionService = SessionService.instance;
              final currentSession =
                  await OdooSessionManager.getCurrentSession();

              if (currentSession != null) {
                WidgetsBinding.instance.addPostFrameCallback((_) {
                  context.read<CompanyProvider>().initialize();
                  context.read<ProfileProvider>().fetchUserProfile();
                });
                await sessionService.storeAccount(
                  currentSession,
                  currentSession.password,
                  markAsCurrent: true,
                );
              }
            } catch (e) {}
          }
        }
      } catch (e) {
        inventoryInstalled = true;
        /// Keep as false; the MissingInventoryScreen will allow retry
      }
    }

    return {
      'isLoggedIn': isLoggedIn,
      'biometricEnabled': biometricEnabled,
      'inventoryInstalled': inventoryInstalled,
      'missingModules': missingModule,
      'hasSeenGetStarted': hasSeenGetStarted,
    };
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<Map<String, dynamic>>(
      future: _initFuture,
      builder: (context, snapshot) {
        if (snapshot.connectionState != ConnectionState.done) {
          return const Scaffold(body: Center(child: LoadingIndicator()));
        }

        if (snapshot.hasError || snapshot.data == null) {
          return const ServerSetupScreen();
        }
        final missingModules =
            snapshot.data!['missingModules'] as List<String>? ?? [];
        final isLoggedIn = snapshot.data!['isLoggedIn'] as bool;
        final biometricEnabled = snapshot.data!['biometricEnabled'] as bool;
        final inventoryInstalled =
            snapshot.data!['inventoryInstalled'] as bool? ?? false;

        /// Check if biometric should be skipped
        final biometricContext = BiometricContextService();
        final shouldSkipBiometric =
            widget.skipBiometric || biometricContext.shouldSkipBiometric;

        /// Show biometric lock screen if enabled and logged in
        if (biometricEnabled &&
            isLoggedIn &&
            !shouldSkipBiometric &&
            inventoryInstalled) {
          return AppLockScreen(
            onAuthenticationSuccess: () {
              /// After biometric unlock, re-enter AppEntry (skipping biometric)
              /// so that startup checks (including inventory module check)
              /// can run and route either to HomeScaffold or MissingInventoryScreen.
              Navigator.pushReplacement(
                context,
                dynamicRoute(context, const AppEntry(skipBiometric: true)),
              );
            },
          );
        } else if (isLoggedIn) {
          final userRoleProvider = context.watch<UserTypeRoleCheckProvider>();
          if (userRoleProvider.groupIds.isEmpty) {
            /// Only refetch if a session still exists, to avoid racing a concurrent logout.
            if (SessionService.instance.currentSession != null) {
              WidgetsBinding.instance.addPostFrameCallback((_) {
                context.read<UserTypeRoleCheckProvider>().fetchAndSetUserRole();
              });
            }
            return const Scaffold(body: Center(child: LoadingIndicator()));
          }

          if (userRoleProvider.isPortal || userRoleProvider.isPublic) {
            if (!_roleDialogShown) {
              _roleDialogShown = true;
              WidgetsBinding.instance.addPostFrameCallback((_) {
                showDialog(
                  context: context,
                  barrierDismissible: false,
                  builder: (_) => const WidgetShowRoleTypeDialog(),
                );
              });
            }
            return const ServerSetupScreen();
          }
          /// If logged in but inventory not installed, show guidance screen
          WidgetsBinding.instance.addPostFrameCallback((_) {
            final roleProvider = context.read<RoleProvider>();

            /// Same staleness guard as above -- skip refetch if no live session.
            if (roleProvider.role == null &&
                SessionService.instance.currentSession != null) {
              roleProvider.loadRole().then((_) {
                if (roleProvider.isAdmin) {
                } else if (roleProvider.isOfficer) {
                } else {}
              });
            }
          });

          if (!inventoryInstalled) {
            WidgetsBinding.instance.addPostFrameCallback((_) {
              showDialog(
                context: context,
                barrierDismissible: false,
                builder: (_) => ModuleCheckDialog(moduleName: missingModules),
              );
            });

            return const ServerSetupScreen();
          }

          final roleProvider = context.watch<RoleProvider>();

          ///  Wait for role
          if (roleProvider.role == null) {
            return const Scaffold(body: Center(child: LoadingIndicator()));
          }

          /// Admin → existing navbar
          if (roleProvider.isAdmin) {
            return const ManagerBottomNavbarPage();
          }

          /// Officer → manager navbar
          return const BottonnavbarPage();
        }

        /// Not logged in, show login screen
        final hasSeenGetStarted =
            snapshot.data!['hasSeenGetStarted'] as bool? ?? false;
        if (!hasSeenGetStarted) {
          return const GetStartedScreen();
        }
        return const ServerSetupScreen();
      },
    );
  }
}
