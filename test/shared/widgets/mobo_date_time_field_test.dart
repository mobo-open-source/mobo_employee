import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hugeicons/hugeicons.dart';
import 'package:mobo_employees/core/const/all_design.dart';
import 'package:mobo_employees/core/theme/app_theme.dart';
import 'package:mobo_employees/shared/widgets/forms/mobo_date_time_field.dart';

Widget _field({DateTime? value, String label = 'Check In'}) {
  return MaterialApp(
    home: Scaffold(
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: MoboDateTimeField(label: label, value: value, onChanged: (_) {}),
      ),
    ),
  );
}

/// The icons drawn in the field, left to right.
List<List<List<dynamic>>> _icons(WidgetTester tester) => tester
    .widgetList<HugeIcon>(find.byType(HugeIcon))
    .map((icon) => icon.icon)
    .toList();

void main() {
  _timePickerTests();

  testWidgets('leads with a calendar icon, not a clock', (tester) async {
    await tester.pumpWidget(_field(value: DateTime(2026, 11, 5, 15, 57)));

    final icons = _icons(tester);
    expect(icons.first, HugeIcons.strokeRoundedCalendar03);
    expect(icons, isNot(contains(HugeIcons.strokeRoundedClock01)));
  });

  testWidgets('the empty field has the calendar icon too', (tester) async {
    await tester.pumpWidget(_field(label: 'Check Out'));

    expect(_icons(tester).first, HugeIcons.strokeRoundedCalendar03);
    expect(find.text('Select date & time'), findsOneWidget);
  });

  testWidgets('still shows the date and the time', (tester) async {
    await tester.pumpWidget(_field(value: DateTime(2026, 11, 5, 15, 57)));

    expect(find.text('Nov 05, 2026  03:57 PM'), findsOneWidget);
  });
}

/// The attendance create form's Check In field, taken through to the time
/// picker's typing mode.
Future<void> _openTimeTyping(WidgetTester tester) async {
  await tester.tap(find.text('Select date & time'));
  await tester.pumpAndSettle();
  // The date comes first.
  await tester.tap(find.text('OK'));
  await tester.pumpAndSettle();
  // Then the time, on its dial: switch to typing it.
  await tester.tap(find.byIcon(Icons.keyboard_outlined));
  await tester.pumpAndSettle();
}

void _timePickerTests() {
  group('typing a time', () {
    testWidgets('the caret is white, so it shows on the brand-filled hour', (
      tester,
    ) async {
      await tester.pumpWidget(_field());
      await _openTimeTyping(tester);

      final hour = tester.widget<EditableText>(find.byType(EditableText).first);
      expect(hour.cursorColor, Colors.white);
      // The brand colour it used to be is what disappeared into the fill.
      expect(hour.cursorColor, isNot(AppColors.appColor));
    });

    testWidgets('a text selection is a pale white wash', (tester) async {
      await tester.pumpWidget(_field());
      await _openTimeTyping(tester);

      // A field only paints a selection while it has focus: put it in the hour,
      // as someone about to type would.
      await tester.tap(find.byType(EditableText).first);
      await tester.pump();

      final hour = tester.widget<EditableText>(find.byType(EditableText).first);
      expect(hour.selectionColor, Colors.white.withValues(alpha: 0.35));
    });

    testWidgets('the same goes for the minute', (tester) async {
      await tester.pumpWidget(_field());
      await _openTimeTyping(tester);

      final minute = tester.widget<EditableText>(
        find.byType(EditableText).last,
      );
      expect(minute.cursorColor, Colors.white);
    });

    testWidgets('the drag handle under the hour is white too — not a brand-red '
        'bump on the box', (tester) async {
      await tester.pumpWidget(_field());
      await _openTimeTyping(tester);

      // What the hour field itself is themed with, inside the real picker.
      final inPicker = TextSelectionTheme.of(
        tester.element(find.byType(EditableText).first),
      );
      expect(inPicker.selectionHandleColor, Colors.white);
      expect(inPicker.cursorColor, Colors.white);
      // Nothing about the typing marker is the brand colour any more.
      for (final color in [
        inPicker.selectionHandleColor,
        inPicker.cursorColor,
        inPicker.selectionColor,
      ]) {
        expect(color, isNot(AppColors.appColor));
        expect(color, isNot(AppTheme.primaryColor));
      }
    });

    testWidgets('a field outside the picker keeps its normal caret', (
      tester,
    ) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(body: TextField(controller: TextEditingController())),
        ),
      );

      // The white caret is the picker's own: it does not leak into other fields.
      final field = tester.widget<EditableText>(find.byType(EditableText));
      expect(field.cursorColor, isNot(Colors.white));
    });
  });
}
