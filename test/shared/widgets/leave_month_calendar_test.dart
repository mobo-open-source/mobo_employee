import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mobo_employees/core/const/all_design.dart';
import 'package:mobo_employees/core/theme/app_theme.dart';
import 'package:mobo_employees/shared/widgets/calendar/leave_month_calendar.dart';

/// March 2026: the 1st is a Sunday, the 31st a Tuesday.
final _march = DateTime(2026, 3, 15);

Widget _calendar({
  DateTime? month,
  DateTime? selected,
  DateTime? today,
  List<LeaveCalendarMark> marks = const [],
  Map<DateTime, bool> unusual = const {},
  ValueChanged<DateTime>? onSelect,
  VoidCallback? onPrevious,
  VoidCallback? onNext,
  Brightness brightness = Brightness.light,
}) {
  return MaterialApp(
    theme: ThemeData(brightness: brightness),
    home: Scaffold(
      body: SingleChildScrollView(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: LeaveMonthCalendar(
            month: month ?? _march,
            selectedDate: selected,
            today: today ?? DateTime(2026, 3, 12),
            marks: marks,
            unusualDays: unusual,
            onSelectDate: onSelect ?? (_) {},
            onPreviousMonth: onPrevious ?? () {},
            onNextMonth: onNext ?? () {},
          ),
        ),
      ),
    ),
  );
}

Finder _day(int day) => find.byKey(ValueKey('calendar_day_$day'));

/// The 6x6 status dots drawn in day [day]'s cell.
Finder _dotsIn(int day) => find.descendant(
  of: _day(day),
  matching: find.byWidgetPredicate(
    (w) =>
        w is Container &&
        w.constraints?.maxWidth == 6 &&
        w.constraints?.maxHeight == 6,
  ),
);

/// The number circle of day [day]: its fill and its outline.
({Color? fill, Border? border}) _circle(WidgetTester tester, int day) {
  final container = tester.widget<Container>(
    find.descendant(of: _day(day), matching: find.byType(Container)).first,
  );
  final decoration = container.decoration as BoxDecoration;
  return (fill: decoration.color, border: decoration.border as Border?);
}

LeaveCalendarMark _mark(int fromDay, int toDay, Color color) =>
    LeaveCalendarMark(
      from: DateTime(2026, 3, fromDay),
      to: DateTime(2026, 3, toDay),
      color: color,
    );

void main() {
  group('layout', () {
    testWidgets('shows the month, the day names and the legend', (
      tester,
    ) async {
      await tester.pumpWidget(_calendar());

      expect(find.text('March 2026'), findsOneWidget);
      for (final name in ['SUN', 'MON', 'TUE', 'WED', 'THU', 'FRI', 'SAT']) {
        expect(find.text(name), findsOneWidget);
      }
      for (final label in ['Validated', 'To Approve', 'Refused']) {
        expect(find.text(label), findsOneWidget);
      }
    });

    testWidgets('has one cell per day, starting under the right weekday', (
      tester,
    ) async {
      // April 2026 has 30 days and the 1st falls on a Wednesday.
      await tester.pumpWidget(_calendar(month: DateTime(2026, 4, 1)));

      expect(_day(30), findsOneWidget);
      expect(_day(31), findsNothing);

      final grid = tester.getRect(find.byType(GridView));
      final column = grid.width / 7;
      final first = tester.getCenter(_day(1));
      expect(first.dx, closeTo(grid.left + column * 3.5, 1));
      // Rows are the events calendar's height.
      expect(tester.getSize(_day(1)).height, LeaveMonthCalendar.rowHeight);
    });

    testWidgets('fits a narrow screen without overflowing', (tester) async {
      tester.view.physicalSize = const Size(320, 800);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);

      await tester.pumpWidget(
        _calendar(
          marks: [for (var i = 0; i < 5; i++) _mark(10, 10, Colors.red)],
        ),
      );

      expect(tester.takeException(), isNull);
    });
  });

  group('the events-app look', () {
    testWidgets('the arrows and the month are brand-filled', (tester) async {
      await tester.pumpWidget(_calendar());

      final month = tester.widget<Container>(
        find
            .ancestor(
              of: find.text('March 2026'),
              matching: find.byType(Container),
            )
            .first,
      );
      expect((month.decoration as BoxDecoration).color, AppTheme.primaryColor);
      final text = tester.widget<Text>(find.text('March 2026'));
      expect(text.style?.color, Colors.white);

      // The brand-filled Material around each arrow (not the transparent one
      // inside the IconButton).
      for (final tooltip in ['Previous month', 'Next month']) {
        expect(
          find.ancestor(
            of: find.byTooltip(tooltip),
            matching: find.byWidgetPredicate(
              (w) => w is Material && w.color == AppTheme.primaryColor,
            ),
          ),
          findsOneWidget,
          reason: tooltip,
        );
      }
    });

    testWidgets('the weekday strip is the pale brand tint', (tester) async {
      await tester.pumpWidget(_calendar());

      final strip = tester.widget<Container>(
        find
            .ancestor(of: find.text('MON'), matching: find.byType(Container))
            .first,
      );
      expect(strip.color, AppColors.primaryTint);
      expect(
        tester.widget<Text>(find.text('MON')).style?.color,
        AppTheme.primaryColor,
      );
    });

    testWidgets('today is a pale filled circle', (tester) async {
      await tester.pumpWidget(_calendar(today: DateTime(2026, 3, 12)));

      expect(_circle(tester, 12).fill, const Color(0xFFF6DCDC));
      expect(_circle(tester, 12).border, isNull);
      expect(_circle(tester, 13).fill, isNull);
    });

    testWidgets('the selected day is a 2px brand ring', (tester) async {
      await tester.pumpWidget(_calendar(selected: DateTime(2026, 3, 20)));

      final ring = _circle(tester, 20).border!;
      expect(ring.top.color, AppTheme.primaryColor);
      expect(ring.top.width, 2);
      expect(_circle(tester, 21).border, isNull);
    });

    testWidgets('a selected today shows the ring, not the fill', (
      tester,
    ) async {
      await tester.pumpWidget(
        _calendar(
          today: DateTime(2026, 3, 12),
          selected: DateTime(2026, 3, 12),
        ),
      );

      expect(_circle(tester, 12).border!.top.color, AppTheme.primaryColor);
      expect(_circle(tester, 12).fill, isNull);
    });

    testWidgets('a holiday or non-working day is greyed', (tester) async {
      await tester.pumpWidget(_calendar(unusual: {DateTime(2026, 3, 7): true}));

      Color? colorOf(int day) => tester
          .widget<Text>(
            find.descendant(of: _day(day), matching: find.text('$day')),
          )
          .style
          ?.color;
      expect(colorOf(7), AppColors.greyShade500Color);
      expect(colorOf(8), AppColors.blackColor);
    });
  });

  group('time off', () {
    testWidgets('shows a dot per time off, in its status colour', (
      tester,
    ) async {
      await tester.pumpWidget(
        _calendar(
          marks: [
            _mark(10, 10, AppColors.color007AFF),
            _mark(10, 10, AppColors.colorFFAA00),
          ],
        ),
      );

      final dots = tester.widgetList<Container>(_dotsIn(10)).toList();
      expect(dots.map((d) => (d.decoration as BoxDecoration).color), [
        AppColors.color007AFF,
        AppColors.colorFFAA00,
      ]);
      expect(_dotsIn(11), findsNothing);
    });

    testWidgets('a range marks every day it covers', (tester) async {
      await tester.pumpWidget(_calendar(marks: [_mark(10, 12, Colors.red)]));

      expect(_dotsIn(9), findsNothing);
      for (final day in [10, 11, 12]) {
        expect(_dotsIn(day), findsOneWidget, reason: 'day $day');
      }
      expect(_dotsIn(13), findsNothing);
    });

    testWidgets('more than three collapse into a +N', (tester) async {
      await tester.pumpWidget(
        _calendar(
          marks: [for (var i = 0; i < 5; i++) _mark(10, 10, Colors.red)],
        ),
      );

      expect(_dotsIn(10), findsNWidgets(LeaveMonthCalendar.maxDots));
      expect(
        find.descendant(of: _day(10), matching: find.text('+2')),
        findsOneWidget,
      );
    });
  });

  group('taps', () {
    testWidgets('tapping a day selects it', (tester) async {
      DateTime? picked;
      await tester.pumpWidget(_calendar(onSelect: (d) => picked = d));

      await tester.tap(_day(18));
      expect(picked, DateTime(2026, 3, 18));
    });

    testWidgets('the arrows go to the previous and next month', (tester) async {
      var previous = 0;
      var next = 0;
      await tester.pumpWidget(
        _calendar(onPrevious: () => previous++, onNext: () => next++),
      );

      await tester.tap(find.byTooltip('Next month'));
      await tester.tap(find.byTooltip('Next month'));
      await tester.tap(find.byTooltip('Previous month'));

      expect(next, 2);
      expect(previous, 1);
    });
  });

  testWidgets('dark mode inverts the strip and keeps the brand buttons', (
    tester,
  ) async {
    await tester.pumpWidget(_calendar(brightness: Brightness.dark));

    final strip = tester.widget<Container>(
      find
          .ancestor(of: find.text('MON'), matching: find.byType(Container))
          .first,
    );
    expect(strip.color, Colors.white.withValues(alpha: 0.12));
    expect(tester.widget<Text>(find.text('MON')).style?.color, Colors.white);

    final month = tester.widget<Container>(
      find
          .ancestor(
            of: find.text('March 2026'),
            matching: find.byType(Container),
          )
          .first,
    );
    expect((month.decoration as BoxDecoration).color, AppTheme.primaryColor);
  });
}
