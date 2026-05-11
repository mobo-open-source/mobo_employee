import 'package:flutter/material.dart';
import 'package:flutter_speed_dial/flutter_speed_dial.dart';
import 'package:mobo_employees/core/const/all_design.dart';

import 'package:provider/provider.dart';

import '../provider/leave_page_provider.dart';
import '../service/leave_service.dart';
import 'my_time_off_add.dart';

class WidgetSpeedDial extends StatelessWidget {
  const WidgetSpeedDial({super.key});

  @override
  Widget build(BuildContext context) {
    return Consumer<LeavePageProvider>(
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
            _openBottomSheet(context);
            await LeaveService.fetchTimeOffTypes();
          },
        );
      },
    );
  }

  void _openBottomSheet(BuildContext context) {
    showModalBottomSheet(
      isDismissible: false,
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => MyTimeOffAdd(),
    );
  }
}
