import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mobo_employees/core/const/all_design.dart';
import 'package:mobo_employees/core/theme/app_theme.dart';
import 'package:mobo_employees/shared/widgets/sheets/filter_bottom_sheet.dart';

Widget _sheet(Brightness brightness) {
  return MaterialApp(
    theme: ThemeData(brightness: brightness),
    home: Scaffold(
      body: FilterBottomSheet<String, String>(
        filterSections: const [
          FilterSection(title: 'Schedule', [
            ('today', 'Today'),
            ('week', 'This Week'),
          ]),
        ],
        initialSelected: const {'today'},
        groupByOptions: const [GroupByOption('none', 'None', 'No grouping')],
        initialGroupBy: const {'none'},
        onApply: (_, __, ___, ____) async {},
        onClearAll: () async {},
      ),
    ),
  );
}

ChoiceChip _chip(WidgetTester tester, String label) =>
    tester.widget<ChoiceChip>(find.widgetWithText(ChoiceChip, label));

TextStyle? _labelStyle(ChoiceChip chip) => (chip.label as Text).style;

BorderSide _side(ChoiceChip chip) =>
    (chip.shape! as RoundedRectangleBorder).side;

void main() {
  group('dark mode', () {
    testWidgets('an option at rest is a neutral grey box with white text', (
      tester,
    ) async {
      await tester.pumpWidget(_sheet(Brightness.dark));

      final chip = _chip(tester, 'This Week');
      // Opaque grey, as the events app's filter chips — not the pink wash.
      expect(chip.backgroundColor, AppTheme.darkOptionFill);
      expect(chip.backgroundColor!.a, 1.0);
      expect(chip.backgroundColor, isNot(AppTheme.primaryWash));
      expect(_side(chip).color, AppTheme.darkOptionBorder);
      expect(_labelStyle(chip)?.color, Colors.white);
      expect(_labelStyle(chip)?.fontWeight, FontWeight.w600);
    });

    testWidgets('a picked option is brand-filled with white text', (
      tester,
    ) async {
      await tester.pumpWidget(_sheet(Brightness.dark));

      final chip = _chip(tester, 'Today');
      expect(chip.selected, isTrue);
      expect(chip.selectedColor, AppColors.appColor);
      expect(_side(chip).color, AppColors.appColor);
      expect(_labelStyle(chip)?.color, Colors.white);
    });

    testWidgets('picking an option turns it brand and leaves the rest grey', (
      tester,
    ) async {
      await tester.pumpWidget(_sheet(Brightness.dark));

      await tester.tap(find.widgetWithText(ChoiceChip, 'This Week'));
      await tester.pump();

      expect(_chip(tester, 'This Week').selected, isTrue);
      expect(_side(_chip(tester, 'This Week')).color, AppColors.appColor);
    });
  });

  group('light mode (unchanged)', () {
    testWidgets('an option at rest keeps the pale brand wash and dark text', (
      tester,
    ) async {
      await tester.pumpWidget(_sheet(Brightness.light));

      final chip = _chip(tester, 'This Week');
      expect(chip.backgroundColor, AppTheme.primaryWash);
      expect(_side(chip).color, Colors.grey[300]);
      expect(_labelStyle(chip)?.color, Colors.black87);
      expect(_labelStyle(chip)?.fontWeight, FontWeight.w400);
    });
  });
}
