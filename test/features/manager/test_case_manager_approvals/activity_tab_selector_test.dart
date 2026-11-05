import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mobo_employees/core/const/all_design.dart';
import 'package:mobo_employees/features/manager/manager_approvals/widgets/page_index_click.dart'
    as approvals;
import 'package:mobo_employees/widgets/managers/index_click_common_widget/page_index_click.dart'
    as leave;

Widget _tabs({required bool isDark, int selected = 0}) {
  return MaterialApp(
    home: Scaffold(
      body: leave.CommonActivityTabSelector(
        tabs: const ['Calendar', 'Time Off', 'Allocation'],
        selectedIndex: selected,
        onChanged: (_) {},
        isDarkTheme: isDark,
      ),
    ),
  );
}

/// The chip [index]'s box: its fill and its outline colour.
({Color? fill, Color? border}) _chip(WidgetTester tester, int index) {
  final box = tester.widget<Container>(
    find
        .descendant(
          of: find.byKey(Key('activity_tab_$index')),
          matching: find.byType(Container),
        )
        .first,
  );
  final decoration = box.decoration as BoxDecoration;
  return (
    fill: decoration.color,
    border: (decoration.border as Border).top.color,
  );
}

void main() {
  testWidgets('an idle chip is white with a #EDEDEB outline', (tester) async {
    await tester.pumpWidget(_tabs(isDark: false));

    for (final index in [1, 2]) {
      final chip = _chip(tester, index);
      expect(chip.fill, AppColors.whiteColor, reason: 'chip $index fill');
      expect(chip.border, AppColors.colorEDEDEB, reason: 'chip $index border');
    }
    expect(AppColors.colorEDEDEB, const Color(0xFFEDEDEB));
  });

  testWidgets('the selected chip stays solid black', (tester) async {
    await tester.pumpWidget(_tabs(isDark: false, selected: 1));

    final chip = _chip(tester, 1);
    expect(chip.fill, AppColors.blackColor);
    expect(chip.border, AppColors.blackColor);
    // ...and the one it replaced is idle again.
    expect(_chip(tester, 0).fill, AppColors.whiteColor);
  });

  testWidgets('dark mode keeps its grey idle chip and white selected chip', (
    tester,
  ) async {
    await tester.pumpWidget(_tabs(isDark: true));

    expect(_chip(tester, 0).fill, AppColors.whiteColor);
    expect(_chip(tester, 1).fill, AppColors.greyShade800Color);
    expect(_chip(tester, 1).border, AppColors.greyShade800Color);
  });

  test('the Approvals and Leave pages share one widget', () {
    // Two copies used to exist, and a fix to one missed the other.
    expect(
      identical(
        approvals.CommonActivityTabSelector,
        leave.CommonActivityTabSelector,
      ),
      isTrue,
    );
  });
}
