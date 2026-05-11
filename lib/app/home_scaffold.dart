import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:hugeicons/hugeicons.dart';
import 'package:mobo_employees/core/routing/page_transition.dart';
import 'package:mobo_employees/core/services/connectivity_service.dart';
import 'package:mobo_employees/core/services/odoo_session_manager.dart';
import 'package:mobo_employees/widgets/snackbar_widgets.dart';
import 'package:mobo_employees/features/company/providers/company_provider.dart';
import 'package:mobo_employees/features/company/widgets/company_selector_widget.dart';
import 'package:mobo_employees/features/profile/pages/profile_screen.dart';
import 'package:mobo_employees/features/profile/providers/profile_provider.dart';
import 'package:mobo_employees/shared/widgets/connection_status_banner.dart';
import 'package:shimmer/shimmer.dart';
import 'package:provider/provider.dart';
/// Providers for refreshing data after company switch

class HomeScaffold extends StatefulWidget {
  const HomeScaffold({super.key});

  @override
  State<HomeScaffold> createState() => _HomeScaffoldState();
}

class _HomeScaffoldState extends State<HomeScaffold>
    with WidgetsBindingObserver {
  late final List<String> _titles;
  bool _isStockUser = false;
  bool _isLoadingSession = true;

  @override
  void initState() {
    super.initState();
    _titles = const [
      'Dashboard',
      'Inventory',
      'Transfer',
      'Replenishment',
      'History',
    ];
    WidgetsBinding.instance.addObserver(this);
    /// Start connectivity/internet monitoring and seed current server URL
    ConnectivityService.instance.startMonitoring();
    OdooSessionManager.getCurrentSession().then((session) {
      ConnectivityService.instance.setCurrentServerUrl(session?.serverUrl);
      if (mounted) {
        setState(() {
          _isStockUser = session?.isStockUser ?? false;
          _isLoadingSession = false;
        });
      }
    });

    /// Ensure ProfileProvider fetches user data on app start
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        context.read<ProfileProvider>().fetchUserProfile();
      }
    });
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    super.didChangeAppLifecycleState(state);
    if (state == AppLifecycleState.resumed) {
      _validateSession();
      /// Refresh profile data (including avatar) when app resumes
      if (mounted) {
        context.read<ProfileProvider>().fetchUserProfile(forceRefresh: true);
      }
    }
  }

  Future<void> _validateSession() async {
    try {
      final isValid = await OdooSessionManager.isSessionValid();
      if (!isValid && mounted) {
        Navigator.of(
          context,
        ).pushNamedAndRemoveUntil('/server_setup', (route) => false);
      } else if (mounted) {
        /// Refresh permission check on resume
        final session = await OdooSessionManager.getCurrentSession();
        if (session != null && session.isStockUser != _isStockUser) {
          setState(() {
            _isStockUser = session.isStockUser;
          });
        }
      }
    } catch (e) {}
  }

  @override
  Widget build(BuildContext context) {
    /// CompanyProvider is now provided globally in main.dart
    return Scaffold(body: _buildScreenWithAppBar(Container()));
  }

  Widget _buildScreenWithAppBar(Widget screen) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Scaffold(
      appBar: AppBar(
        automaticallyImplyLeading: false,
        title: Text(
          "home",
          style: TextStyle(
            color: isDark ? Colors.white : Colors.black,
            fontWeight: FontWeight.bold,
          ),
        ),
        actions: _buildProfileActions(context),
        backgroundColor: Theme.of(context).scaffoldBackgroundColor,
        foregroundColor: isDark ? Colors.white : Theme.of(context).primaryColor,
        elevation: 0,
        centerTitle: false,
        surfaceTintColor: Colors.transparent,
      ),
      body: Stack(
        children: [
          /// Main content
          Positioned.fill(child: screen),
          /// Overlay connection status banner without consuming AppBar bottom height
          Positioned(
            top: 0,
            left: 0,
            right: 0,
            child: IgnorePointer(
              ignoring: true,
              child: const ConnectionStatusBanner(),
            ),
          ),
        ],
      ),
    );
  }

  List<Widget> _buildProfileActions(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return [
      /// Company selector
      CompanySelectorWidget(
        onCompanyChanged: () async {
          if (!mounted) return;

          /// Get the newly selected company name for better feedback
          final provider = context.read<CompanyProvider>();
          final companyName =
              provider.selectedCompany?['name']?.toString() ?? 'company';

          /// Refresh profile data
          await context.read<ProfileProvider>().fetchUserProfile(
            forceRefresh: true,
          );

          ///Show success message
          CustomSnackbar.showSuccess(context, 'Switched to $companyName');

          ///Reload all feature providers with new company context
        },
      ),
      Container(
        margin: const EdgeInsets.only(right: 8),
        child: Consumer<ProfileProvider>(
          builder: (context, profileProvider, child) {
            final userAvatar = profileProvider.userAvatar;
            final isLoading = profileProvider.isLoading && userAvatar == null;

            return IconButton(
              icon: AnimatedSwitcher(
                duration: const Duration(milliseconds: 200),
                child: isLoading
                    ? SizedBox(
                        key: const ValueKey('avatar_loading'),
                        width: 32,
                        height: 32,
                        child: Shimmer.fromColors(
                          baseColor: isDark
                              ? Colors.grey[700]!
                              : Colors.grey[300]!,
                          highlightColor: isDark
                              ? Colors.grey[600]!
                              : Colors.grey[200]!,
                          child: Container(
                            decoration: BoxDecoration(
                              color: isDark ? Colors.grey[800] : Colors.white,
                              shape: BoxShape.circle,
                            ),
                          ),
                        ),
                      )
                    : (userAvatar != null
                          ? CircleAvatar(
                              key: const ValueKey('avatar_with_image'),
                              radius: 16,
                              backgroundColor: isDark
                                  ? Colors.grey[800]
                                  : Colors.grey[300],
                              backgroundImage: MemoryImage(userAvatar),
                            )
                          : CircleAvatar(
                              key: const ValueKey('avatar_placeholder'),
                              radius: 16,
                              backgroundColor: isDark
                                  ? Colors.grey[800]
                                  : Colors.grey[300],
                              child: HugeIcon(
                                icon: HugeIcons.strokeRoundedUserCircle,
                                color: isDark ? Colors.white70 : Colors.black54,
                                size: 18,
                              ),
                            )),
              ),
              onPressed: () {
                Navigator.push(
                  context,
                  dynamicRoute(context, const ProfileScreen()),
                ).then((_) {
                  /// Refresh profile data after returning from profile screen
                  if (mounted) {
                    context.read<ProfileProvider>().fetchUserProfile(
                      forceRefresh: true,
                    );
                  }
                });
              },
            );
          },
        ),
      ),
    ];
  }
}
