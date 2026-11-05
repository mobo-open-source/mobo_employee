import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mobo_employees/core/const/all_design.dart';
import 'package:mobo_employees/shared/widgets/navigation/mobo_bottom_nav_bar.dart';

/// Three tabs, the middle one (Attendance) selected.
Widget _bar({
  required Brightness brightness,
  int index = 1,
  ValueChanged<int>? onTap,
}) {
  return MaterialApp(
    theme: ThemeData(brightness: brightness),
    home: Scaffold(
      bottomNavigationBar: MoboBottomNavBar(
        currentIndex: index,
        onTap: onTap ?? (_) {},
        items: const [
          BottomNavigationBarItem(
            icon: Icon(Icons.dashboard),
            label: 'Dashboard',
          ),
          BottomNavigationBarItem(icon: Icon(Icons.task), label: 'Attendance'),
          BottomNavigationBarItem(icon: Icon(Icons.people), label: 'Employees'),
        ],
      ),
    ),
  );
}

/// The colour [icon] is actually drawn in — what the bar hands it through the
/// ambient icon theme.
Color? _iconColor(WidgetTester tester, IconData icon) =>
    IconTheme.of(tester.element(find.byIcon(icon))).color;

void main() {
  group('the selected tab', () {
    testWidgets('is the Mobo brand colour in dark mode — not white', (
      tester,
    ) async {
      await tester.pumpWidget(_bar(brightness: Brightness.dark));

      expect(_iconColor(tester, Icons.task), AppColors.appColor);
      expect(_iconColor(tester, Icons.task), isNot(Colors.white));
    });

    testWidgets('is the Mobo brand colour in light mode too', (tester) async {
      await tester.pumpWidget(_bar(brightness: Brightness.light));

      expect(_iconColor(tester, Icons.task), AppColors.appColor);
    });

    testWidgets('follows the selection', (tester) async {
      await tester.pumpWidget(_bar(brightness: Brightness.dark, index: 2));

      expect(_iconColor(tester, Icons.people), AppColors.appColor);
      expect(_iconColor(tester, Icons.task), isNot(AppColors.appColor));
    });

    testWidgets('has a brand-coloured selected tab in the helper too', (
      tester,
    ) async {
      expect(MoboBottomNavBar.selectedColor(true), AppColors.appColor);
      expect(MoboBottomNavBar.selectedColor(false), AppColors.appColor);
    });
  });

  group('the other tabs', () {
    testWidgets('stay light grey in dark mode', (tester) async {
      await tester.pumpWidget(_bar(brightness: Brightness.dark));

      expect(_iconColor(tester, Icons.dashboard), AppColors.grey50);
      expect(_iconColor(tester, Icons.people), AppColors.grey50);
    });

    testWidgets('stay black in light mode', (tester) async {
      await tester.pumpWidget(_bar(brightness: Brightness.light));

      expect(_iconColor(tester, Icons.dashboard), AppColors.blackColor);
    });
  });

  group('the bar', () {
    testWidgets('keeps its dark surface in dark mode and white in light', (
      tester,
    ) async {
      await tester.pumpWidget(_bar(brightness: Brightness.dark));
      expect(
        MoboBottomNavBar.backgroundColor(true),
        AppColors.greyShade900Color,
      );

      await tester.pumpWidget(_bar(brightness: Brightness.light));
      await tester.pumpAndSettle();
      expect(MoboBottomNavBar.backgroundColor(false), AppColors.whiteColor);
    });

    testWidgets('shows the tabs and reports a tap', (tester) async {
      int? tapped;
      await tester.pumpWidget(
        _bar(brightness: Brightness.dark, onTap: (i) => tapped = i),
      );

      for (final label in ['Dashboard', 'Attendance', 'Employees']) {
        expect(find.text(label), findsOneWidget);
      }
      await tester.tap(find.text('Employees'));
      // Let the snake indicator finish sliding across.
      await tester.pumpAndSettle();
      expect(tapped, 2);
    });
  });
}
