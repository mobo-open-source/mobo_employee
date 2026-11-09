import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mobo_employees/core/const/all_design.dart';
import 'package:mobo_employees/features/manager/manager_approvals/models/model_time_off_add_employees.dart';
import 'package:mobo_employees/features/manager/manager_attendance/widgets/attendance_create_sheet.dart';
import 'package:mobo_employees/shared/widgets/loaders/loading_widget.dart';
import 'package:mobo_employees/shared/widgets/sheets/form_sheet_shell.dart';
import 'package:mobo_employees/shared/widgets/sheets/sheet_submit_button.dart';

/// Opens New Attendance through its real entry point, with the server stood in
/// for: [save] is what "Save" calls.
Widget _app({
  Future<void> Function({
    required int employeeId,
    required DateTime checkIn,
    DateTime? checkOut,
  })?
  save,
  required ValueNotifier<bool?> result,
}) {
  return MaterialApp(
    home: Builder(
      builder: (context) => Scaffold(
        body: Center(
          child: ElevatedButton(
            onPressed: () async {
              result.value = await AttendanceCreateSheet.show(
                context,
                employeeDomain: const [],
                loadEmployees: (_) async => [
                  Employee(id: 7, name: 'Mitchell Admin'),
                ],
                saveAttendance:
                    save ??
                    ({
                      required employeeId,
                      required checkIn,
                      checkOut,
                    }) async {},
              );
            },
            child: const Text('open'),
          ),
        ),
      ),
    ),
  );
}

Future<void> _open(WidgetTester tester) async {
  await tester.tap(find.text('open'));
  await tester.pumpAndSettle();
}

/// Picks Mitchell Admin in the Employee field, which is what lets Save through.
Future<void> _pickEmployee(WidgetTester tester) async {
  await tester.tap(find.byType(TextField).first);
  await tester.pump(const Duration(seconds: 1));
  await tester.pumpAndSettle();
  await tester.tap(find.text('Mitchell Admin').last);
  await tester.pumpAndSettle();
}

/// The popup's visible card. (`Dialog` itself fills the whole route; the card
/// is the Material inside it.)
Finder get _surface => find
    .descendant(of: find.byType(Dialog), matching: find.byType(Material))
    .first;

void _tall(WidgetTester tester) {
  tester.view.physicalSize = const Size(800, 1200);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
}

void main() {
  late ValueNotifier<bool?> result;

  setUp(() => result = ValueNotifier<bool?>(null));

  group('as a popup', () {
    testWidgets('opens in the middle of the screen, not as a bottom sheet', (
      tester,
    ) async {
      _tall(tester);
      await tester.pumpWidget(_app(result: result));
      await _open(tester);

      expect(find.byType(Dialog), findsOneWidget);
      expect(find.byType(BottomSheet), findsNothing);

      final dialog = tester.getRect(_surface);
      final screen = tester.view.physicalSize;
      expect(dialog.center.dx, closeTo(screen.width / 2, 1));
      expect(dialog.center.dy, closeTo(screen.height / 2, 1));
      // Floating, not docked to the bottom edge.
      expect(dialog.bottom, lessThan(screen.height - 20));
      expect(dialog.top, greaterThan(20));
    });

    testWidgets('is rounded on every corner', (tester) async {
      _tall(tester);
      await tester.pumpWidget(_app(result: result));
      await _open(tester);

      final shape =
          tester.widget<Dialog>(find.byType(Dialog)).shape
              as RoundedRectangleBorder;
      expect(
        shape.borderRadius,
        BorderRadius.circular(FormSheetShell.popupRadius),
      );
    });

    testWidgets('keeps the heading, the grey rule and the fields', (
      tester,
    ) async {
      _tall(tester);
      await tester.pumpWidget(_app(result: result));
      await _open(tester);

      expect(find.text('New Attendance'), findsOneWidget);
      expect(find.byType(Divider), findsOneWidget);
      expect(find.textContaining('Check In'), findsWidgets);
    });

    testWidgets('the × closes it', (tester) async {
      _tall(tester);
      await tester.pumpWidget(_app(result: result));
      await _open(tester);

      await tester.tap(
        find
            .descendant(
              of: find.byType(FormSheetShell),
              matching: find.byType(InkWell),
            )
            .first,
      );
      await tester.pumpAndSettle();

      expect(find.byType(Dialog), findsNothing);
      expect(result.value, isFalse);
    });
  });

  group('the action', () {
    testWidgets('has no Cancel, and one large full-width Save', (tester) async {
      _tall(tester);
      await tester.pumpWidget(_app(result: result));
      await _open(tester);

      expect(find.text('Cancel'), findsNothing);
      expect(find.byType(OutlinedButton), findsNothing);

      final save = tester.getRect(find.byType(SheetSubmitButton));
      final dialog = tester.getRect(_surface);
      expect(save.height, SheetSubmitButton.height);
      expect(save.left - dialog.left, FormSheetShell.inset);
      expect(dialog.right - save.right, FormSheetShell.inset);
      expect(tester.widget<Text>(find.text('Save')).style?.fontSize, 16);
    });

    testWidgets('has an even 20 under it', (tester) async {
      _tall(tester);
      await tester.pumpWidget(_app(result: result));
      await _open(tester);

      final save = tester.getRect(find.byType(SheetSubmitButton));
      final dialog = tester.getRect(_surface);
      expect(dialog.bottom - save.bottom, FormSheetShell.footerGap);
    });

    testWidgets('is inactive until an employee is chosen', (tester) async {
      _tall(tester);
      await tester.pumpWidget(_app(result: result));
      await _open(tester);

      expect(
        tester
            .widget<ElevatedButton>(find.byType(ElevatedButton).last)
            .onPressed,
        isNull,
      );

      await _pickEmployee(tester);
      expect(
        tester
            .widget<ElevatedButton>(find.byType(ElevatedButton).last)
            .onPressed,
        isNotNull,
      );
    });
  });

  group('saving', () {
    // The Save button, as the user sees it.
    ElevatedButton saveButton(WidgetTester tester) => tester.widget(
      find.descendant(
        of: find.byType(SheetSubmitButton),
        matching: find.byType(ElevatedButton),
      ),
    );

    testWidgets('the Save button shows the loading, and the popup closes once '
        'it is saved', (tester) async {
      _tall(tester);
      final saving = Completer<void>();
      await tester.pumpWidget(
        _app(
          result: result,
          save: ({required employeeId, required checkIn, checkOut}) =>
              saving.future,
        ),
      );
      await _open(tester);
      await _pickEmployee(tester);
      expect(find.text('Save'), findsOneWidget);

      await tester.tap(find.byType(SheetSubmitButton));
      await tester.pump(const Duration(milliseconds: 300));

      // The progress is in the button — "Saving..." and its dots — in place of
      // "Save"...
      expect(find.text('Saving...'), findsOneWidget);
      expect(find.text('Save'), findsNothing);
      // ...which stays brand-coloured, and cannot be pressed twice.
      final button = saveButton(tester);
      expect(button.onPressed, isNull);
      expect(
        button.style!.backgroundColor!.resolve({WidgetState.disabled}),
        AppColors.colorC03355,
      );
      // Nothing covers the form any more: no loading animation or message, and
      // the fields are still there to see.
      expect(find.byType(LoadingWidget), findsNothing);
      expect(find.text('Saving attendance...'), findsNothing);
      // (Required fields' labels are rich text, with their red *.)
      expect(
        find.textContaining('Employee', findRichText: true),
        findsOneWidget,
      );
      expect(
        find.textContaining('Check In', findRichText: true),
        findsOneWidget,
      );
      // Still the one popup — not a second dialog on top of it.
      expect(find.byType(Dialog), findsOneWidget);
      // The × is dead while it saves.
      expect(
        tester
            .widget<InkWell>(
              find
                  .descendant(
                    of: find.byType(FormSheetShell),
                    matching: find.byType(InkWell),
                  )
                  .first,
            )
            .onTap,
        isNull,
      );

      // Not yet saved: it has not closed.
      expect(result.value, isNull);

      saving.complete();
      await tester.pumpAndSettle();

      // Saved: the popup closes, and says it created the attendance.
      expect(find.byType(Dialog), findsNothing);
      expect(result.value, isTrue);
    });

    testWidgets('the fields cannot be changed while it saves', (tester) async {
      _tall(tester);
      final saving = Completer<void>();
      await tester.pumpWidget(
        _app(
          result: result,
          save: ({required employeeId, required checkIn, checkOut}) =>
              saving.future,
        ),
      );
      await _open(tester);
      await _pickEmployee(tester);
      await tester.tap(find.byType(SheetSubmitButton));
      await tester.pump(const Duration(milliseconds: 300));

      await tester.tap(find.text('Still checked in'), warnIfMissed: false);
      await tester.pump(const Duration(milliseconds: 300));
      expect(find.byType(DatePickerDialog), findsNothing);

      saving.complete();
      await tester.pumpAndSettle();
    });

    testWidgets('a failed save brings the form back', (tester) async {
      _tall(tester);
      await tester.pumpWidget(
        _app(
          result: result,
          save: ({required employeeId, required checkIn, checkOut}) async =>
              throw Exception('boom'),
        ),
      );
      await _open(tester);
      await _pickEmployee(tester);

      await tester.tap(find.byType(SheetSubmitButton));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));

      // The popup is still open and the loader is gone: the user can retry.
      expect(find.byType(Dialog), findsWidgets);
      expect(find.byType(LoadingWidget), findsNothing);
      expect(find.text('New Attendance'), findsOneWidget);

      // Let the error toast's own timer run out.
      await tester.pump(const Duration(seconds: 4));
      await tester.pumpAndSettle();
    });
  });
}
