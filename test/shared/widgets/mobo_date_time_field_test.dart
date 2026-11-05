import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hugeicons/hugeicons.dart';
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
