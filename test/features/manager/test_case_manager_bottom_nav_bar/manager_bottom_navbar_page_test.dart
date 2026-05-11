import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'fake_manager_bottom_navbar_provider.dart';

void main() {
  group("Manager Bottom NavBar Page Unit Test", () {
    test('Index change', () {
      final provider = FakeManagerBottomNavbarProvider();
      expect(provider.index, 0);
      provider.screenIndex(3);
      expect(provider.index, 3);
    });

    test('Current index after logout', () {
      final provider = FakeManagerBottomNavbarProvider();
      provider.screenIndex(3);
      provider.clearOnLogout();
      expect(provider.index, 0);
    });
  });
}
