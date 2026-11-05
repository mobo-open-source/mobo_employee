import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mobo_employees/features/manager/manager_attendance/widgets/attendance_table.dart';

AttendanceTableEntry _entry(
  String name, {
  String checkIn = '09:51 PM',
  String checkOut = '-',
  String? checkOutDate,
  String worked = '00:00',
}) => AttendanceTableEntry(
  name: name,
  avatar: null,
  date: 'Nov 05',
  checkIn: checkIn,
  checkOut: checkOut,
  checkOutDate: checkOutDate,
  worked: worked,
);

Widget _table(
  List<AttendanceTableEntry> entries, {
  Brightness brightness = Brightness.light,
}) {
  return MaterialApp(
    theme: ThemeData(brightness: brightness),
    home: Scaffold(
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: AttendanceTable(entries: entries),
      ),
    ),
  );
}

final _four = [
  _entry('Audrey Peterson'),
  _entry('David Miller', checkIn: '09:30 AM'),
  _entry(
    'Marcus Vance',
    checkIn: '08:30 AM',
    checkOut: '05:15 PM',
    worked: '08:45',
  ),
  _entry(
    'Sophia Chen',
    checkIn: '09:05 AM',
    checkOut: '06:00 PM',
    worked: '08:55',
  ),
];

Finder get _headerBand => find
    .ancestor(of: find.text('EMPLOYEE'), matching: find.byType(Container))
    .first;

void main() {
  void wide(WidgetTester tester) {
    tester.view.physicalSize = const Size(1000, 900);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
  }

  group('the heading', () {
    testWidgets('names the columns in bold capitals', (tester) async {
      wide(tester);
      await tester.pumpWidget(_table(_four));

      for (final heading in ['EMPLOYEE', 'CHECK IN', 'CHECK OUT', 'WORKED']) {
        final style = tester.widget<Text>(find.text(heading)).style;
        expect(style?.fontWeight, FontWeight.w700, reason: heading);
      }
    });

    testWidgets(
      'is white with a rule under it — not a tinted band or a bordered box',
      (tester) async {
        wide(tester);
        await tester.pumpWidget(_table(_four));

        final decoration =
            tester.widget<Container>(_headerBand).decoration as BoxDecoration;
        // No rounded corners and no border all round...
        expect(decoration.borderRadius, isNull);
        final border = decoration.border! as Border;
        expect(border.top, BorderSide.none);
        expect(border.left, BorderSide.none);
        expect(border.right, BorderSide.none);
        // ...just the rule beneath.
        expect(border.bottom.width, 1);
        expect(border.bottom.color, const Color(0xFFE2E8F0));
        expect(decoration.color, Colors.white);
        // The same white as the card around it.
        final card = tester.widget<Container>(
          find
              .descendant(
                of: find.byType(AttendanceTable),
                matching: find.byType(Container),
              )
              .first,
        );
        expect((card.decoration as BoxDecoration).color, decoration.color);
      },
    );

    testWidgets('runs the full width of the card, edge to edge', (
      tester,
    ) async {
      wide(tester);
      await tester.pumpWidget(_table(_four));

      final band = tester.getRect(_headerBand);
      final card = tester.getRect(find.byType(AttendanceTable));
      expect(band.left, card.left);
      expect(band.right, card.right);
      expect(band.height, AttendanceTable.headerHeight);
    });
  });

  group('the rows', () {
    testWidgets('show the name, the day and the times', (tester) async {
      wide(tester);
      await tester.pumpWidget(_table(_four));

      for (final name in [
        'Audrey Peterson',
        'David Miller',
        'Marcus Vance',
        'Sophia Chen',
      ]) {
        expect(find.text(name), findsOneWidget);
      }
      expect(find.text('Nov 05'), findsNWidgets(4));
      expect(find.text('09:51 PM'), findsOneWidget);
      expect(find.text('05:15 PM'), findsOneWidget);
      // No check-out yet reads "-".
      expect(find.text('-'), findsNWidgets(2));
    });

    testWidgets('set the check-in, check-out and worked times in bold', (
      tester,
    ) async {
      wide(tester);
      await tester.pumpWidget(_table(_four));

      for (final time in [
        '09:51 PM',
        '09:30 AM',
        '05:15 PM',
        '06:00 PM',
        '08:45',
      ]) {
        final style = tester.widget<Text>(find.text(time)).style;
        expect(style?.fontWeight, FontWeight.w600, reason: time);
        expect(style?.color, const Color(0xFF0F172A), reason: time);
      }
    });

    testWidgets(
      'are 70 tall, with a hairline between them but not after the last',
      (tester) async {
        wide(tester);
        await tester.pumpWidget(_table(_four));

        Container rowOf(String name) => tester.widget<Container>(
          find
              .ancestor(of: find.text(name), matching: find.byType(Container))
              .first,
        );
        Border? borderOf(String name) =>
            (rowOf(name).decoration as BoxDecoration).border as Border?;

        expect(
          tester
              .getSize(
                find
                    .ancestor(
                      of: find.text('Audrey Peterson'),
                      matching: find.byType(Container),
                    )
                    .first,
              )
              .height,
          AttendanceTable.rowHeight,
        );
        for (final name in [
          'Audrey Peterson',
          'David Miller',
          'Marcus Vance',
        ]) {
          expect(
            borderOf(name)?.bottom.color,
            const Color(0xFFF1F5F9),
            reason: name,
          );
        }
        expect(borderOf('Sophia Chen'), isNull);
      },
    );

    testWidgets('centre each time under its heading', (tester) async {
      wide(tester);
      await tester.pumpWidget(_table(_four));

      double centreX(Finder f) => tester.getCenter(f).dx;
      expect(
        centreX(find.text('09:51 PM')),
        closeTo(centreX(find.text('CHECK IN')), 1),
      );
      expect(
        centreX(find.text('05:15 PM')),
        closeTo(centreX(find.text('CHECK OUT')), 1),
      );
      expect(
        centreX(find.text('08:45')),
        closeTo(centreX(find.text('WORKED')), 1),
      );
    });

    testWidgets('put the day beside the name, on the same line', (
      tester,
    ) async {
      wide(tester);
      await tester.pumpWidget(_table([_entry('Audrey Peterson')]));

      final name = tester.getRect(find.text('Audrey Peterson'));
      final day = tester.getRect(find.text('Nov 05'));
      expect(day.left, greaterThan(name.right));
      expect(day.center.dy, closeTo(name.center.dy, 2));
    });

    testWidgets('give an overnight check-out its own day under the time', (
      tester,
    ) async {
      wide(tester);
      await tester.pumpWidget(
        _table([
          _entry('Night Owl', checkOut: '06:00 AM', checkOutDate: 'Nov 06'),
        ]),
      );

      final time = tester.getRect(find.text('06:00 AM'));
      final caption = tester.getRect(find.text('Nov 06'));
      expect(caption.top, greaterThanOrEqualTo(time.bottom));
    });

    testWidgets('use the initial in a brand circle when there is no photo', (
      tester,
    ) async {
      wide(tester);
      await tester.pumpWidget(_table([_entry('Audrey Peterson')]));

      expect(find.text('A'), findsOneWidget);
    });
  });

  group('size', () {
    testWidgets(
      'is a notch smaller than before: a 44 heading, 60 rows, a 34 photo',
      (tester) async {
        wide(tester);
        await tester.pumpWidget(_table(_four));

        expect(AttendanceTable.headerHeight, 44);
        expect(AttendanceTable.rowHeight, 60);
        expect(AttendanceTable.avatarSize, 34);

        // The four rows and the heading are all the card holds.
        final card = tester.getRect(find.byType(AttendanceTable));
        expect(
          card.height,
          closeTo(
            AttendanceTable.headerHeight + AttendanceTable.rowHeight * 4,
            1,
          ),
        );
      },
    );

    testWidgets('keeps the times bold at 13 and the names at 13', (
      tester,
    ) async {
      wide(tester);
      await tester.pumpWidget(_table(_four));

      expect(tester.widget<Text>(find.text('09:30 AM')).style?.fontSize, 13);
      expect(
        tester.widget<Text>(find.text('09:30 AM')).style?.fontWeight,
        FontWeight.w600,
      );
      expect(
        tester.widget<Text>(find.text('David Miller')).style?.fontSize,
        13,
      );
    });
  });

  group('width', () {
    testWidgets(
      'on a 390dp phone it shows the employee and check-in, and the rest is a swipe away',
      (tester) async {
        tester.view.physicalSize = const Size(390, 800);
        tester.view.devicePixelRatio = 1;
        addTearDown(tester.view.reset);

        await tester.pumpWidget(_table(_four));
        expect(tester.takeException(), isNull);

        final card = tester.getRect(find.byType(AttendanceTable));
        // Employee and Check In are in view, whole...
        for (final heading in ['EMPLOYEE', 'CHECK IN']) {
          final rect = tester.getRect(find.text(heading));
          expect(rect.left, greaterThanOrEqualTo(card.left), reason: heading);
          expect(rect.right, lessThanOrEqualTo(card.right), reason: heading);
        }
        // ...the table is wider than the card rather than squeezed into it...
        expect(AttendanceTable.minTableWidth, greaterThan(card.width));
        expect(
          tester.getRect(find.text('WORKED')).left,
          greaterThan(card.right),
        );

        // ...and swiping sideways brings the last column into view.
        await tester.drag(
          find.byType(SingleChildScrollView).last,
          const Offset(-400, 0),
        );
        await tester.pump();
        expect(
          tester.getRect(find.text('WORKED')).right,
          lessThanOrEqualTo(card.right),
        );
      },
    );

    testWidgets('the columns are spaced apart, not squeezed together', (
      tester,
    ) async {
      wide(tester);
      await tester.pumpWidget(_table(_four));

      double centreX(String heading) => tester.getCenter(find.text(heading)).dx;
      // Centre to centre, a column is as wide as it is made — roomy.
      expect(
        centreX('CHECK OUT') - centreX('CHECK IN'),
        closeTo(
          (AttendanceTable.checkInWidth + AttendanceTable.checkOutWidth) / 2,
          1,
        ),
      );
      expect(
        centreX('WORKED') - centreX('CHECK OUT'),
        closeTo(
          (AttendanceTable.checkOutWidth + AttendanceTable.workedWidth) / 2,
          1,
        ),
      );
      expect(
        centreX('CHECK OUT') - centreX('CHECK IN'),
        greaterThanOrEqualTo(90),
      );

      // A time has air either side of it within its column.
      final time = tester.getRect(find.text('09:30 AM'));
      final column = AttendanceTable.checkInWidth;
      expect(time.width, lessThanOrEqualTo(column));
    });

    testWidgets('the day is clear of the check-in time, with a real gap', (
      tester,
    ) async {
      tester.view.physicalSize = const Size(1000, 900);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);

      await tester.pumpWidget(_table([_entry('Anita Oliver')]));

      final day = tester.getRect(find.text('Nov 05'));
      final checkIn = tester.getRect(find.text('09:51 PM'));
      expect(checkIn.left - day.right, greaterThanOrEqualTo(24));
    });

    testWidgets('a time stays on one line, scaled to its column if need be', (
      tester,
    ) async {
      tester.view.physicalSize = const Size(390, 800);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);

      await tester.pumpWidget(_table(_four));

      for (final time in ['09:51 PM', '05:15 PM', '08:45']) {
        final rect = tester.getRect(find.text(time));
        // One line: no taller than a line of 13px text.
        expect(rect.height, lessThan(20), reason: time);
        expect(tester.widget<Text>(find.text(time)).maxLines, 1, reason: time);
      }
    });

    testWidgets('a long name is shortened rather than pushing the times out', (
      tester,
    ) async {
      tester.view.physicalSize = const Size(800, 800);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);

      await tester.pumpWidget(
        _table([
          _entry(
            'Bartholomew Maximilian Featherstonehaugh',
            checkOut: '05:15 PM',
          ),
        ]),
      );

      expect(tester.takeException(), isNull);
      final card = tester.getRect(find.byType(AttendanceTable));
      expect(
        tester.getRect(find.text('05:15 PM')).right,
        lessThanOrEqualTo(card.right),
      );
      expect(
        tester.widget<Text>(find.textContaining('Bartholomew')).overflow,
        TextOverflow.ellipsis,
      );
    });

    testWidgets('a really narrow card scrolls sideways instead of overflowing', (
      tester,
    ) async {
      tester.view.physicalSize = const Size(300, 800);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);

      await tester.pumpWidget(_table(_four));
      expect(tester.takeException(), isNull);

      // The table is wider than the card, so the last column is off to the right...
      final worked = tester.getRect(find.text('WORKED'));
      expect(worked.left, greaterThan(300));

      // ...and reachable by dragging.
      await tester.drag(
        find.byType(SingleChildScrollView).last,
        const Offset(-400, 0),
      );
      await tester.pump();
      expect(tester.getRect(find.text('WORKED')).right, lessThanOrEqualTo(300));
    });

    testWidgets('a wide card gives the extra to the employee column', (
      tester,
    ) async {
      wide(tester);
      await tester.pumpWidget(_table(_four));

      final card = tester.getRect(find.byType(AttendanceTable));
      final workedHeading = tester.getRect(find.text('WORKED'));
      // The times stay their fixed width at the right edge; the table fills
      // the card.
      expect(card.width, closeTo(1000 - 32, 1));
      expect(
        card.right - workedHeading.right,
        lessThan(AttendanceTable.workedWidth),
      );
    });
  });

  group('dark mode', () {
    testWidgets('the card is the dark card grey with light text', (
      tester,
    ) async {
      wide(tester);
      await tester.pumpWidget(_table(_four, brightness: Brightness.dark));

      final card = tester.widget<Container>(
        find
            .descendant(
              of: find.byType(AttendanceTable),
              matching: find.byType(Container),
            )
            .first,
      );
      expect((card.decoration as BoxDecoration).color, Colors.grey[850]);
      expect(
        tester.widget<Text>(find.text('09:30 AM')).style?.color,
        Colors.white,
      );
    });
  });
}
