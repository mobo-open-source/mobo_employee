import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mobo_employees/shared/widgets/filters/date_range_filter_fields.dart';

Widget _fields({
  DateTime? start,
  DateTime? end,
  ValueChanged<DateTime?>? onStartChanged,
}) {
  return MaterialApp(
    home: Scaffold(
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: DateRangeFilterFields(
          startDate: start,
          endDate: end,
          startPlaceholder: 'Start Date',
          endPlaceholder: 'End Date',
          onStartChanged: onStartChanged ?? (_) {},
          onEndChanged: (_) {},
        ),
      ),
    ),
  );
}

/// Height of the tappable field around [text].
double _fieldHeight(WidgetTester tester, String text) => tester
    .getSize(
      find.ancestor(of: find.text(text), matching: find.byType(InkWell)).first,
    )
    .height;

void main() {
  group('isValid', () {
    test('either end may be open', () {
      expect(DateRangeFilterFields.isValid(null, null), isTrue);
      expect(DateRangeFilterFields.isValid(DateTime(2026, 10, 1), null), isTrue);
      expect(DateRangeFilterFields.isValid(null, DateTime(2026, 10, 1)), isTrue);
    });

    test('the same day is a valid range, whatever the time of day', () {
      expect(
        DateRangeFilterFields.isValid(
          DateTime(2026, 10, 1, 18),
          DateTime(2026, 10, 1, 9),
        ),
        isTrue,
      );
    });

    test('a start after the end is not', () {
      expect(
        DateRangeFilterFields.isValid(
          DateTime(2026, 10, 20),
          DateTime(2026, 10, 1),
        ),
        isFalse,
      );
    });
  });

  testWidgets('a field is 44px tall empty and filled', (tester) async {
    await tester.pumpWidget(_fields());
    expect(_fieldHeight(tester, 'Start Date'), 44);

    await tester.pumpWidget(_fields(start: DateTime(2026, 10, 1)));
    expect(_fieldHeight(tester, 'From: Oct 01, 2026'), 44);
  });

  testWidgets('a reversed range explains itself under the fields', (
    tester,
  ) async {
    await tester.pumpWidget(
      _fields(start: DateTime(2026, 10, 20), end: DateTime(2026, 10, 1)),
    );
    await tester.pumpAndSettle();

    expect(find.text(DateRangeFilterFields.rangeError), findsOneWidget);
  });

  testWidgets('the clear button empties its field', (tester) async {
    DateTime? cleared = DateTime(2000);
    await tester.pumpWidget(
      _fields(
        start: DateTime(2026, 10, 1),
        onStartChanged: (value) => cleared = value,
      ),
    );

    await tester.tap(find.byIcon(Icons.clear));
    await tester.pump();

    expect(cleared, isNull);
  });
}
