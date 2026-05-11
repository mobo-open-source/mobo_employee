import 'package:flutter/material.dart';
import 'package:flutter_speed_dial/flutter_speed_dial.dart';
import 'package:mobo_employees/core/const/all_design.dart';
import 'package:mobo_employees/features/manager/manager_approvals/providers/manager_approvals_provider.dart';
import 'package:mobo_employees/features/manager/manager_approvals/widgets/widget_manager_time_off_add_page.dart';
import 'package:provider/provider.dart';

class WidgetManagerSpeedDial extends StatelessWidget {
  const WidgetManagerSpeedDial({super.key});

  @override
  Widget build(BuildContext context) {
    return Consumer<ManagerApprovalsProvider>(
      builder: (context, provider, _) {
        return SpeedDial(
          icon: Icons.add,
          activeIcon: Icons.close,
          backgroundColor: AppColors.appColor,
          foregroundColor: Colors.white,
          overlayColor: Colors.black,
          overlayOpacity: 0.3,
          spacing: 12,
          spaceBetweenChildren: 12,
          elevation: 4,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(15),
          ),

          onPress: () async {
            _openManagerTimeOffBottomSheet(context);
            await provider.fetchEmployees();
          },
        );
      },
    );
  }

  void _openManagerTimeOffBottomSheet(BuildContext context) {
    showModalBottomSheet(
      isDismissible: false,
      context: context,
      isScrollControlled: true,
      enableDrag: false,
      backgroundColor: Colors.transparent,
      builder: (context) => WidgetManagerTimeOffAddPage(),
    );
  }
}
