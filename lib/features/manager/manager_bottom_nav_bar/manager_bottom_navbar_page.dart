import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:hugeicons/hugeicons.dart';
import 'package:mobo_employees/core/routing/page_transition.dart';
import 'package:mobo_employees/features/company/providers/company_provider.dart';
import 'package:mobo_employees/features/company/widgets/company_selector_widget.dart';
import 'package:mobo_employees/features/employee/bottom_navigation_bar/bottom_navigation_bar_provider.dart';
import 'package:mobo_employees/features/manager/manager_approvals/pages/manager_approvals_page.dart';
import 'package:mobo_employees/features/manager/manager_attendance/page/manager_attendance_page.dart';
import 'package:mobo_employees/features/manager/manager_dashboard/page/manager_dashboard_page.dart';
import 'package:mobo_employees/features/manager/manager_employees/page/manager_employees_page.dart';
import 'package:mobo_employees/features/profile/pages/profile_screen.dart';
import 'package:mobo_employees/features/profile/providers/profile_provider.dart';
import 'package:mobo_employees/features/roles_check/role_refresh.dart';
import 'package:mobo_employees/shared/widgets/avatars/initials_avatar.dart';
import 'package:provider/provider.dart';
import 'package:shimmer/shimmer.dart';
import '../../../core/const/all_design.dart';
import '../../../widgets/snackbar_widgets.dart';
import '../../../shared/providers/clear_provider.dart';
import 'package:mobo_employees/shared/widgets/navigation/mobo_bottom_nav_bar.dart';

class ManagerBottomNavbarPage extends StatefulWidget {
  final int initialIndex;
  final int? activityTabIndex;
  final int? vehicleId;
  const ManagerBottomNavbarPage({
    super.key,
    this.initialIndex = 0,
    this.vehicleId,
    this.activityTabIndex,
  });

  @override
  State<ManagerBottomNavbarPage> createState() =>
      _ManagerBottomNavbarPageState();
}

class _ManagerBottomNavbarPageState extends State<ManagerBottomNavbarPage> {
  late int _currentIndex;
  int? _vehicleId;
  int? _activityTabIndex;

  /// Bumped on a company switch: the tab on screen is rebuilt from scratch,
  /// so it reloads for the new company like on first open. (Clearing the
  /// providers alone left it empty or loading forever.)
  int _companyGeneration = 0;

  @override
  void initState() {
    super.initState();
    _currentIndex = widget.initialIndex;
    _vehicleId = widget.vehicleId;
    _activityTabIndex = widget.activityTabIndex;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<ProfileProvider>().ensureLoaded();
    });
  }

  List<Widget> get screens => [
    ManagerDashboardPage(onOpenTab: _onItemTapped),
    ManagerAttendancePage(),
    ManagerEmployeesPage(),
    ManagerApprovalsPage(),
  ];

  final List<String> _titles = const [
    'Dashboard',
    "Attendance",
    'Employees',
    'Approvals',
  ];

  void _onItemTapped(int index) {
    setState(() {
      if (index != 3) {
        _vehicleId = null;
        _activityTabIndex = null;
      }
      _currentIndex = index;
    });

    /// The user's manager groups may have been removed in Odoo since the
    /// view opened.
    refreshUserRole(context);
  }

  @override
  Widget build(BuildContext context) {
    final scaffold = Theme.of(context).scaffoldBackgroundColor;
    final bool isDarkTheme = Theme.of(context).brightness == Brightness.dark;
    return Scaffold(
      appBar: AppBar(
        surfaceTintColor: Colors.transparent,
        backgroundColor: scaffold,

        /// The status bar is the page's own colour — `#FAFAFA` in the Figma
        /// frames — flush with the title bar under it, with icons that
        /// contrast with it. Stated rather than left to AppBar's guess from the
        /// background, so it can't drift from the design.
        systemOverlayStyle:
            (isDarkTheme
                    ? SystemUiOverlayStyle.light
                    : SystemUiOverlayStyle.dark)
                .copyWith(statusBarColor: scaffold),
        automaticallyImplyLeading: false,
        elevation: 0,
        title: Text(
          _titles[_currentIndex],
          style: TextStyle(
            fontSize: 21,
            fontWeight: FontWeight.w600,
            color: isDarkTheme ? AppColors.whiteColor : AppColors.blackColor,
            letterSpacing: 0,
          ),
        ),
        actions: _buildProfileActions(context),
      ),
      body: KeyedSubtree(
        key: ValueKey(_companyGeneration),
        child: screens[_currentIndex],
      ),
      bottomNavigationBar: MoboBottomNavBar(
        currentIndex: _currentIndex,
        onTap: _onItemTapped,
        items: [
          BottomNavigationBarItem(
            icon: HugeIcon(
              icon: HugeIcons.strokeRoundedDashboardSquare01,
              size: 25,
            ),
            label: 'Dashboard',
          ),
          BottomNavigationBarItem(
            icon: HugeIcon(icon: HugeIcons.strokeRoundedTask01, size: 25),
            label: 'Attendance',
          ),
          BottomNavigationBarItem(
            icon: HugeIcon(
              icon: HugeIcons.strokeRoundedUserMultiple02,
              size: 25,
            ),
            label: 'Employees',
          ),
          BottomNavigationBarItem(
            icon: HugeIcon(
              icon: HugeIcons.strokeRoundedDocumentValidation,
              size: 25,
            ),
            label: 'Approvals',
          ),
        ],
      ),
    );
  }

  List<Widget> _buildProfileActions(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return [
      CompanySelectorWidget(
        onCompanyChanged: () async {
          if (!mounted) return;
          final provider = context.read<CompanyProvider>();

          final companyName =
              provider.selectedCompany?['name']?.toString() ?? 'company';

          /// Await the clear: it resets ProfileProvider at its end, so an
          /// un-awaited clear could wipe the profile after it was re-fetched.
          await ClearProviders.clearAllProviders(context);
          if (!mounted) return;
          setState(() => _companyGeneration++);
          await context.read<ProfileProvider>().ensureLoaded();
          if (!mounted) return;

          CustomSnackbar.showSuccess(context, 'Switched to $companyName');
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
                          ? ClipOval(
                              key: const ValueKey('avatar_with_image'),
                              child: Image.memory(
                                userAvatar,
                                width: 32,
                                height: 32,
                                fit: BoxFit.cover,
                                errorBuilder: (context, error, stackTrace) =>
                                    InitialsAvatar(
                                      name: profileProvider.userData?['name']
                                          ?.toString(),
                                      diameter: 32,
                                    ),
                              ),
                            )
                          : InitialsAvatar(
                              key: const ValueKey('avatar_placeholder'),
                              name: profileProvider.userData?['name']
                                  ?.toString(),
                              diameter: 32,
                            )),
              ),
              onPressed: () {
                Navigator.push(
                  context,
                  dynamicRoute(context, const ProfileScreen()),
                ).then((_) {
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
