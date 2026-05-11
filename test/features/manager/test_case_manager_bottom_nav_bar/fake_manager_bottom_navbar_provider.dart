import 'package:mobo_employees/features/manager/manager_bottom_nav_bar/manager_bottom_navbar_provider.dart';

class FakeManagerBottomNavbarProvider extends ManagerBottomNavbarProvider {
  @override
  screenIndex(int clickedIndex) {
    index = clickedIndex;
    notifyListeners();
  }

  @override
  void clearOnLogout() {
    index = 0;
  }
}
