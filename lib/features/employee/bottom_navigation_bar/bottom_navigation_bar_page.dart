import 'package:flutter/material.dart';
import 'package:flutter_snake_navigationbar/flutter_snake_navigationbar.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:hugeicons/hugeicons.dart';
import 'package:mobo_employees/core/routing/page_transition.dart';
import 'package:mobo_employees/widgets/snackbar_widgets.dart';
import 'package:mobo_employees/features/employee/leave/pages/leave_page.dart';
import 'package:mobo_employees/features/company/providers/company_provider.dart';
import 'package:mobo_employees/features/company/widgets/company_selector_widget.dart';
import 'package:mobo_employees/features/employee/attendance/page/attendance_page.dart';
import 'package:mobo_employees/features/employee/bottom_navigation_bar/bottom_navigation_bar_provider.dart';
import 'package:mobo_employees/features/employee/dashboard/page/dashboard_page.dart';
import 'package:mobo_employees/features/profile/pages/profile_screen.dart';
import 'package:mobo_employees/features/profile/providers/profile_provider.dart';
import 'package:mobo_employees/shared/widgets/avatars/initials_avatar.dart';

import 'package:provider/provider.dart';
import 'package:shimmer/shimmer.dart';

import '../../../core/const/all_design.dart';
import '../../../shared/providers/clear_provider.dart';

class BottonnavbarPage extends StatefulWidget {
  final int initialIndex;
  final int? activityTabIndex;
  final int? vehicleId;
  final bool isTest;

  const BottonnavbarPage({
    super.key,
    this.initialIndex = 0,
    this.vehicleId,
    this.activityTabIndex,
    this.isTest = false,
  });

  @override
  State<BottonnavbarPage> createState() => _BottonnavbarPageState();
}

class _BottonnavbarPageState extends State<BottonnavbarPage> {
  late int _currentIndex;
  int? _vehicleId;
  int? _activityTabIndex;

  static const List<String> appBarTitles = [
    'Dashboard',
    'Attendance',
    'Leaves',
  ];

  @override
  void initState() {
    super.initState();
    _currentIndex = widget.initialIndex;
    _vehicleId = widget.vehicleId;
    _activityTabIndex = widget.activityTabIndex;
    if (widget.isTest) return;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<ProfileProvider>().fetchUserProfile();
    });
  }

  List<Widget> get screens => [
    DashboardPage(),
    AttendancePage(),
    LeavePage(),
  ];

  void _onItemTapped(int index) {
    setState(() {
      if (index != 3) {
        _vehicleId = null;
        _activityTabIndex = null;
      }
      _currentIndex = index;
    });
  }

  @override
  Widget build(BuildContext context) {
    final scaffold = Theme.of(context).scaffoldBackgroundColor;
    final bool isDarkTheme = Theme.of(context).brightness == Brightness.dark;
    return Scaffold(
      appBar: AppBar(
        surfaceTintColor: Colors.transparent,
        backgroundColor: scaffold,
        automaticallyImplyLeading: false,
        elevation: 0,
        title: Text(
          appBarTitles[_currentIndex],
          style: TextStyle(
            fontSize: 21,
            fontWeight: FontWeight.w600,
            color: isDarkTheme ? AppColors.whiteColor : AppColors.blackColor,
            letterSpacing: 0,
          ),
        ),
        actions: _buildProfileActions(context),
      ),
      body: screens[_currentIndex],
      bottomNavigationBar: SnakeNavigationBar.color(
        backgroundColor: isDarkTheme
            ? AppColors.greyShade900Color
            : AppColors.whiteColor,
        unselectedItemColor: isDarkTheme
            ? AppColors.grey50
            : AppColors.blackColor,
        selectedItemColor: isDarkTheme
            ? AppColors.whiteColor
            : AppColors.appColor,
        snakeViewColor: AppColors.appColor,
        showSelectedLabels: true,
        showUnselectedLabels: true,
        currentIndex: _currentIndex,
        onTap: _onItemTapped,
        snakeShape: SnakeShape.indicator,
        selectedLabelStyle: GoogleFonts.montserrat(
          fontSize: 10,
          fontWeight: FontWeight.w500,
        ),
        unselectedLabelStyle: GoogleFonts.montserrat(
          fontSize: 10,
          fontWeight: FontWeight.w500,
        ),
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
            icon: HugeIcon(icon: HugeIcons.strokeRoundedCalendar03, size: 25),
            label: 'Leaves',
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
          await context.read<ProfileProvider>().fetchUserProfile(
            forceRefresh: true,
          );

          ClearProviders.clearAllProviders(context);
          await context.read<BottomNavProvider>().refreshAll(context);
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
                              name:
                                  profileProvider.userData?['name']?.toString(),
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
