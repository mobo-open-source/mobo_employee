import 'package:flutter/material.dart';
import 'package:mobo_employees/features/manager/manager_approvals/widgets/widget_manager_allocation_view_page.dart';
import 'package:mobo_employees/features/manager/manager_approvals/widgets/widget_manager_calender_view_page.dart';
import 'package:mobo_employees/features/manager/manager_approvals/widgets/widget_manager_time_off_view_page.dart';

Widget buildSelectedView(int index, BuildContext context) {
  switch (index) {
    case 0:
      return WidgetManagerCalenderViewPage();
    case 1:
      return WidgetManagerTimeOffViewPage();
    case 2:
      return WidgetManagerAllocationViewPage();
    default:
      return const SizedBox.shrink();
  }
}

