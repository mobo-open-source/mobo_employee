import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mobo_employees/features/employee/leave/provider/leave_page_provider.dart';
import 'package:mobo_employees/features/employee/leave/widget/my_time_off_add.dart';
import 'package:mobo_employees/shared/widgets/forms/dashed_border_box.dart';
import 'package:mobo_employees/shared/widgets/sheets/form_sheet_shell.dart';
import 'package:mobo_employees/shared/widgets/sheets/sheet_submit_button.dart';
import 'package:provider/provider.dart';

import 'fake_employee_leave_provider.dart';

/// The sheet's open-time load of leave types goes to the server; not here.
class _Provider extends FakeEmployeeLeaveProvider {
  @override
  Future<void> loadTimeOffTypes() async {}
}

Widget _sheet(LeavePageProvider provider) {
  return ChangeNotifierProvider<LeavePageProvider>.value(
    value: provider,
    child: const MaterialApp(
      home: Scaffold(
        body: Align(alignment: Alignment.bottomCenter, child: MyTimeOffAdd()),
      ),
    ),
  );
}

/// The sheet is taller than the default 800x600 test screen, which would clamp
/// its scroll viewport and skew every measurement.
void _tallScreen(WidgetTester tester) {
  tester.view.physicalSize = const Size(800, 1600);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
}

void main() {
  late _Provider provider;

  setUp(() {
    provider = _Provider();
    addTearDown(provider.dispose);
  });

  testWidgets('has a grey rule right under the Apply for Leave heading', (
    tester,
  ) async {
    _tallScreen(tester);
    await tester.pumpWidget(_sheet(provider));

    final title = tester.getRect(find.text('Apply for Leave'));
    final rule = tester.getRect(find.byType(Divider).first);
    expect(rule.top, greaterThan(title.bottom));
    expect(rule.top - title.bottom, lessThan(24));
    // And the first field is below the rule.
    expect(
      tester
          .getRect(find.textContaining('Leave Type', findRichText: true).first)
          .top,
      greaterThan(rule.bottom),
    );
  });

  testWidgets('has no Cancel button, and one large Submit Request', (
    tester,
  ) async {
    _tallScreen(tester);
    await tester.pumpWidget(_sheet(provider));

    expect(find.text('Cancel'), findsNothing);
    expect(find.byType(OutlinedButton), findsNothing);

    final submit = tester.getRect(find.byType(SheetSubmitButton));
    final sheet = tester.getRect(find.byType(FormSheetShell));
    expect(submit.height, SheetSubmitButton.height);
    expect(submit.left - sheet.left, FormSheetShell.inset);
    expect(sheet.right - submit.right, FormSheetShell.inset);
    expect(find.text('Submit Request'), findsOneWidget);
  });

  testWidgets('the same 20 sits under the button as above it and beside it', (
    tester,
  ) async {
    _tallScreen(tester);
    await tester.pumpWidget(_sheet(provider));

    final sheet = tester.getRect(find.byType(FormSheetShell));
    final submit = tester.getRect(find.byType(SheetSubmitButton));
    final lastField = tester.getRect(find.byType(DashedBorderBox));

    expect(sheet.bottom - submit.bottom, FormSheetShell.footerGap);
    expect(submit.top - lastField.bottom, FormSheetShell.footerGap);
  });

  testWidgets('the file field is a dotted Attach File box, not a button', (
    tester,
  ) async {
    _tallScreen(tester);
    await tester.pumpWidget(_sheet(provider));

    expect(find.byType(DashedBorderBox), findsOneWidget);
    expect(find.text('Attach File'), findsOneWidget);
    // Nothing else on the sheet is a button but Submit Request.
    expect(find.byType(ElevatedButton), findsOneWidget);
    expect(find.byIcon(Icons.attach_file), findsNothing);
  });

  testWidgets('the × is the way out', (tester) async {
    await tester.pumpWidget(
      ChangeNotifierProvider<LeavePageProvider>.value(
        value: provider,
        child: MaterialApp(
          home: Builder(
            builder: (context) => Scaffold(
              body: Center(
                child: ElevatedButton(
                  onPressed: () => showModalBottomSheet(
                    context: context,
                    isScrollControlled: true,
                    backgroundColor: Colors.transparent,
                    builder: (_) =>
                        ChangeNotifierProvider<LeavePageProvider>.value(
                          value: provider,
                          child: const MyTimeOffAdd(),
                        ),
                  ),
                  child: const Text('open'),
                ),
              ),
            ),
          ),
        ),
      ),
    );

    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();
    expect(find.text('Apply for Leave'), findsOneWidget);

    await tester.tap(
      find
          .descendant(
            of: find.byType(FormSheetShell),
            matching: find.byType(InkWell),
          )
          .first,
    );
    await tester.pumpAndSettle();
    expect(find.text('Apply for Leave'), findsNothing);
  });
}
