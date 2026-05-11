import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:mobo_employees/features/manager/manager_dashboard/provider/manager_dashboard_provider.dart';
import 'package:provider/provider.dart';

class ManagerBottomNavbarProvider extends ChangeNotifier {
  int index = 0;

  screenIndex(int clickedIndex) {
    index = clickedIndex;
    notifyListeners();
  }

  Future<void> refreshAll(BuildContext context) async {
    await Future.wait([
      context.read<ManagerDashboardProvider>().refreshDashboard(),
    ]);
  }

  void clearOnLogout() {
    index = 0;
  }
}
