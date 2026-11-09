import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mobo_employees/features/manager/manager_approvals/models/model_time_off_add_employees.dart';
import 'package:mobo_employees/shared/widgets/pickers/employee_typeahead_field.dart';
import 'package:mobo_employees/shared/widgets/sheets/form_sheet_shell.dart';

/// A long list: far more than the dropdown can show at once, so choosing most
/// of them means scrolling the dropdown.
final _employees = [
  for (var i = 1; i <= 40; i++)
    Employee(id: i, name: 'Employee ${i.toString().padLeft(2, '0')}'),
];

/// The Employee field inside the app's create-form sheet, as a bottom sheet
/// (or a popup) opened over a screen.
Widget _app({bool centered = false, required ValueNotifier<Employee?> picked}) {
  return MaterialApp(
    home: Builder(
      builder: (context) => Scaffold(
        body: Center(
          child: ElevatedButton(
            onPressed: () {
              Widget form(BuildContext _) => ValueListenableBuilder<Employee?>(
                valueListenable: picked,
                builder: (context, selected, __) => FormSheetShell(
                  centered: centered,
                  title: 'Apply for Leave',
                  onClose: () => Navigator.pop(context),
                  children: [
                    EmployeeTypeaheadField<Employee>(
                      label: 'Employee',
                      employees: _employees,
                      selectedEmployee: selected,
                      displayName: (e) => e.name,
                      avatarBytes: (e) => e.imageBytes,
                      compareFn: (a, b) => a.id == b.id,
                      onChanged: (e) => picked.value = e,
                    ),
                  ],
                  footer: const SizedBox(height: 52),
                ),
              );
              if (centered) {
                showDialog<void>(context: context, builder: form);
              } else {
                showModalBottomSheet<void>(
                  context: context,
                  isScrollControlled: true,
                  backgroundColor: Colors.transparent,
                  builder: form,
                );
              }
            },
            child: const Text('open'),
          ),
        ),
      ),
    ),
  );
}

void _phone(WidgetTester tester) {
  tester.view.physicalSize = const Size(400, 800);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
}

/// Opens the sheet and the Employee dropdown.
Future<void> _openDropdown(WidgetTester tester) async {
  await tester.tap(find.text('open'));
  await tester.pumpAndSettle();
  await tester.tap(find.byType(TextField));
  // The field waits a moment after a tap before it lists its suggestions.
  await tester.pump(const Duration(milliseconds: 500));
  await tester.pumpAndSettle();
}

/// The dropdown's own list (the only ListView on screen).
Finder get _list => find.byType(ListView);

ScrollableState _scrollable(WidgetTester tester) =>
    tester.state<ScrollableState>(
      find.descendant(of: _list, matching: find.byType(Scrollable)).first,
    );

double _scrolled(WidgetTester tester) => _scrollable(tester).position.pixels;

/// The finger movement that scrolls the dropdown towards its later entries.
/// It opens upward — and so is reversed — when there is little room below the
/// field, as in a bottom sheet; the finger then moves the other way.
Offset _towardsMore(WidgetTester tester, double distance) {
  final reversed = _scrollable(tester).axisDirection == AxisDirection.up;
  return Offset(0, reversed ? distance : -distance);
}

void main() {
  for (final centered in [false, true]) {
    final where = centered ? 'popup' : 'bottom sheet';

    group('the Employee dropdown in a $where', () {
      testWidgets('opens and lists the employees', (tester) async {
        _phone(tester);
        await tester.pumpWidget(
          _app(centered: centered, picked: ValueNotifier(null)),
        );
        await _openDropdown(tester);

        expect(_list, findsOneWidget);
        expect(find.text('Employee 01'), findsOneWidget);
      });

      testWidgets('scrolls when dragged, and stays open while it does', (
        tester,
      ) async {
        _phone(tester);
        await tester.pumpWidget(
          _app(centered: centered, picked: ValueNotifier(null)),
        );
        await _openDropdown(tester);
        expect(_scrolled(tester), 0);

        // A finger drag on the list — what scrolling it is.
        await tester.drag(_list, _towardsMore(tester, 200));
        // Give anything the drag set off (like closing the dropdown) time to
        // happen: it is the frame after the drag, not the drag, that closes it.
        await tester.pump(const Duration(milliseconds: 300));
        await tester.pumpAndSettle();

        expect(_list, findsOneWidget, reason: 'the dropdown closed mid-scroll');
        expect(_scrolled(tester), greaterThan(0));
      });

      testWidgets('lets you scroll to an employee far down and pick them', (
        tester,
      ) async {
        _phone(tester);
        final picked = ValueNotifier<Employee?>(null);
        await tester.pumpWidget(_app(centered: centered, picked: picked));
        await _openDropdown(tester);

        // Not on screen yet.
        expect(find.text('Employee 30'), findsNothing);

        await tester.dragUntilVisible(
          find.text('Employee 30'),
          _list,
          _towardsMore(tester, 150),
        );
        await tester.pumpAndSettle();
        await tester.tap(find.text('Employee 30'));
        await tester.pumpAndSettle();

        expect(picked.value?.name, 'Employee 30');
        // The field now shows them, and the dropdown has closed.
        expect(find.text('Employee 30'), findsOneWidget);
        expect(_list, findsNothing);
      });
    });
  }
  testWidgets('with the keyboard up it still scrolls and picks an employee', (
    tester,
  ) async {
    _phone(tester);
    // A phone's keyboard takes the lower part of the screen.
    tester.view.viewInsets = const FakeViewPadding(bottom: 300);
    final picked = ValueNotifier<Employee?>(null);
    await tester.pumpWidget(_app(picked: picked));
    await _openDropdown(tester);
    expect(_list, findsOneWidget);

    await tester.dragUntilVisible(
      find.text('Employee 25'),
      _list,
      _towardsMore(tester, 120),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text('Employee 25'));
    await tester.pumpAndSettle();

    expect(picked.value?.name, 'Employee 25');
  });
}
