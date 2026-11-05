import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mobo_employees/features/manager/manager_approvals/providers/manager_approvals_provider.dart';
import 'package:mobo_employees/features/manager/manager_approvals/widgets/widget_manager_time_off_add_page.dart';
import 'package:mobo_employees/shared/widgets/forms/dashed_border_box.dart';
import 'package:mobo_employees/shared/widgets/sheets/form_sheet_shell.dart';
import 'package:mobo_employees/shared/widgets/sheets/sheet_submit_button.dart';
import 'package:provider/provider.dart';

import 'fake_manager_approvals_provider.dart';

/// The sheet loads the employee list when it opens; that goes to the server.
class _Provider extends FakeManagerApprovalsProvider {
  @override
  Future<void> fetchEmployees() async {}
}

Widget _sheet(ManagerApprovalsProvider provider) {
  return ChangeNotifierProvider<ManagerApprovalsProvider>.value(
    value: provider,
    child: const MaterialApp(
      home: Scaffold(
        body: Align(
          alignment: Alignment.bottomCenter,
          child: WidgetManagerTimeOffAddPage(),
        ),
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

  testWidgets('has a grey rule between the heading and the Employee field', (
    tester,
  ) async {
    _tallScreen(tester);
    await tester.pumpWidget(_sheet(provider));

    final title = tester.getRect(find.text('Apply for Leave'));
    final rule = tester.getRect(find.byType(Divider).first);
    expect(rule.top, greaterThan(title.bottom));
    expect(
      tester
          .getRect(find.textContaining('Employee', findRichText: true).first)
          .top,
      greaterThan(rule.bottom),
    );
  });

  testWidgets('has no Cancel button, and one large full-width Submit Request', (
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
  });

  testWidgets('has an even 20 above, below and beside the button', (
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

  testWidgets('the file field is a dotted Attach File box', (tester) async {
    _tallScreen(tester);
    await tester.pumpWidget(_sheet(provider));

    expect(find.byType(DashedBorderBox), findsOneWidget);
    expect(find.text('Attach File'), findsOneWidget);
  });
}
