import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:mobo_employees/features/employee/dashboard/provider/dashboard_provider.dart';
import 'package:provider/provider.dart';

class BottomNavProvider extends ChangeNotifier {
  int index = 0;

  screenIndex(int clickedIndex) {
    index = clickedIndex;
    notifyListeners();
  }

  Future<void> refreshAll(BuildContext context) async {
    await Future.wait([context.read<DashboardProvider>().refreshDashboard()]);
  }

  void clearOnLogout() {
    index = 0;
  }
}
