import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mobo_employees/core/theme/app_theme.dart';
import 'package:mobo_employees/features/manager/manager_approvals/widgets/widget_timeoff_card.dart';
import 'package:mobo_employees/features/manager/manager_employees/widgets/widget_employee_card.dart';

Widget _card({
  String status = 'To Approve',
  String state = 'confirm',
  bool statesss = false,
  String reason = 'Personal medical appointment (doctor).',
  String name = 'Beth Evans',
  String? date = '10 Nov',
  String? balance,
}) {
  return MaterialApp(
    home: Scaffold(
      // Loose constraints, as in the page's list (a bare Scaffold body would
      // stretch the card to the screen's height).
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Align(
          alignment: Alignment.topCenter,
          child: WidgetTimeOffCard(
            employeeName: name,
            leaveType: 'Compensatory',
            duration: '1 day',
            date: date,
            balance: balance,
            reason: reason,
            status: status,
            state: state,
            statesss: statesss,
            imageBytes: null,
            isValidating: false,
            isRefusing: false,
            actionName: 'Approve',
            onValidate: () {},
            onRefuse: () {},
          ),
        ),
      ),
    ),
  );
}

Finder get _avatar => find.byWidgetPredicate(
  (w) =>
      w is Container &&
      w.constraints?.maxWidth == WidgetTimeOffCard.avatarSize &&
      w.constraints?.maxHeight == WidgetTimeOffCard.avatarSize,
);

Finder get _details => find.textContaining('Compensatory', findRichText: true);

void main() {
  group('dateLabel', () {
    test('a single day is the day and the month', () {
      expect(
        WidgetTimeOffCard.dateLabel(
          DateTime(2026, 11, 10, 8),
          DateTime(2026, 11, 10, 17),
        ),
        '10 Nov',
      );
    });

    test('a range inside one month shares the month', () {
      expect(
        WidgetTimeOffCard.dateLabel(
          DateTime(2026, 11, 10),
          DateTime(2026, 11, 12),
        ),
        '10-12 Nov',
      );
    });

    test('across months both ends are named', () {
      expect(
        WidgetTimeOffCard.dateLabel(
          DateTime(2026, 11, 28),
          DateTime(2026, 12, 2),
        ),
        '28 Nov - 2 Dec',
      );
    });

    test('across years the years appear too', () {
      expect(
        WidgetTimeOffCard.dateLabel(
          DateTime(2025, 12, 30),
          DateTime(2026, 1, 2),
        ),
        '30 Dec 2025 - 2 Jan 2026',
      );
    });

    test('an unknown end falls back to the given text', () {
      expect(
        WidgetTimeOffCard.dateLabel(
          null,
          DateTime(2026, 11, 10),
          fallback: 'x – y',
        ),
        'x – y',
      );
    });
  });

  test('an allocation balance is "(remaining/total)" to one decimal', () {
    expect(WidgetTimeOffCard.balanceLabel(0, 0), '(0.0/0.0)');
    expect(WidgetTimeOffCard.balanceLabel(7.5, 10), '(7.5/10.0)');
  });

  group('status pill colours', () {
    test('pending is the reference\'s pale blue with dark blue text', () {
      for (final state in ['confirm', 'validate1']) {
        final colors = WidgetTimeOffCard.pillColors(state, false);
        expect(colors.fill, const Color(0xFFDAEEFE), reason: state);
        expect(colors.text, const Color(0xFF0E5794), reason: state);
      }
    });

    test('other states are their semantic colour on a tint of it', () {
      final approved = WidgetTimeOffCard.pillColors('validate', false);
      expect(approved.text, StatusColors.green);
      expect(approved.fill, StatusColors.green.withValues(alpha: 0.12));
      expect(
        WidgetTimeOffCard.pillColors('refuse', false).text,
        StatusColors.red,
      );
    });

    test('dark mode is the translucent white pill', () {
      final colors = WidgetTimeOffCard.pillColors('confirm', true);
      expect(colors.fill, Colors.white.withValues(alpha: 0.15));
      expect(colors.text, Colors.white);
    });
  });

  group('the card', () {
    testWidgets('has 12 of padding on every side', (tester) async {
      await tester.pumpWidget(_card());

      final card = tester.getRect(find.byType(WidgetTimeOffCard));
      final photo = tester.getRect(_avatar);
      final buttons = tester.getRect(find.byType(ElevatedButton));

      // 12 of padding, and the 0.5 of the card's hairline border (a bordered
      // Container pads its child by it).
      expect(photo.left - card.left, 12.5);
      expect(photo.top - card.top, 12.5);
      expect(card.bottom - buttons.bottom, 12.5);
      expect(card.right - buttons.right, 12.5);
    });

    group('the surface', () {
      BoxDecoration surface(WidgetTester tester) {
        final box = tester.widget<Container>(
          find
              .descendant(
                of: find.byType(WidgetTimeOffCard),
                matching: find.byType(Container),
              )
              .first,
        );
        return box.decoration! as BoxDecoration;
      }

      testWidgets('is the Employees list\'s flat card', (tester) async {
        await tester.pumpWidget(_card());

        final decoration = surface(tester);
        expect(decoration, AppTheme.flatCardDecoration(false));
        // White, the default 12 radius, a hairline border and the card shadow —
        // not the soft search-bar shadow it had.
        expect(decoration.color, Colors.white);
        expect(decoration.borderRadius, BorderRadius.circular(12));
        expect(decoration.boxShadow, const [AppShadows.cardShadow]);
        expect((decoration.border! as Border).top.width, 0.5);
        expect((decoration.border! as Border).top.color, Colors.grey[200]);
      });

      test('is literally the same decoration as an Employees card\'s', () {
        for (final dark in [false, true]) {
          expect(
            WidgetTimeOffCard.decoration(dark),
            WidgetEmployeeCard.decoration(dark),
          );
        }
      });

      test(
        'in dark mode is the dark card grey, with the same border colour',
        () {
          final dark = WidgetTimeOffCard.decoration(true);
          expect(dark.color, Colors.grey[850]);
          expect((dark.border! as Border).top.color, Colors.grey[850]);
        },
      );
    });

    testWidgets('sets the name at 15, larger than the reason below it', (
      tester,
    ) async {
      await tester.pumpWidget(_card());

      final name = tester.widget<Text>(find.text('Beth Evans')).style!;
      final reason =
          (tester
                      .widget<RichText>(
                        find.textContaining('Reason:', findRichText: true),
                      )
                      .text
                  as TextSpan)
              .style!;
      expect(name.fontSize, WidgetTimeOffCard.nameFontSize);
      expect(name.fontSize, 15);
      expect(name.fontSize!, greaterThan(reason.fontSize!));
      expect(name.fontWeight, FontWeight.w600);
    });

    testWidgets('the larger name still fits beside the photo, above the '
        'details', (tester) async {
      await tester.pumpWidget(_card());

      final name = tester.getRect(find.text('Beth Evans'));
      final photo = tester.getRect(_avatar);
      expect(tester.takeException(), isNull);
      expect(name.top, greaterThanOrEqualTo(photo.top));
      expect(name.bottom, lessThanOrEqualTo(photo.bottom));
    });

    testWidgets('has a 40 round photo', (tester) async {
      await tester.pumpWidget(_card());

      expect(tester.getSize(_avatar), const Size(40, 40));
      final decoration =
          tester.widget<Container>(_avatar).decoration as BoxDecoration;
      expect(decoration.shape, BoxShape.circle);
    });

    testWidgets(
      'puts the name and the pill on one line, the details under them',
      (tester) async {
        await tester.pumpWidget(_card());

        final name = tester.getRect(find.text('Beth Evans'));
        final pill = tester.getRect(find.text('To Approve'));
        final photo = tester.getRect(_avatar);
        final details = tester.getRect(_details);

        // The pill is at the right of the name, level with it...
        expect(pill.left, greaterThan(name.right));
        expect((pill.center.dy - name.center.dy).abs(), lessThan(8));
        // ...the details sit under the name, at the photo's foot.
        expect(details.top, greaterThan(name.bottom - 2));
        expect(details.bottom, lessThanOrEqualTo(photo.bottom + 2));
        // Both start beside the photo, 12 from it.
        expect(name.left - photo.right, 12);
        expect(details.left, name.left);
      },
    );

    testWidgets('shows the leave type, the bold duration and the dates', (
      tester,
    ) async {
      await tester.pumpWidget(_card());

      expect(
        find.text('Compensatory · 1 day · 10 Nov', findRichText: true),
        findsOneWidget,
      );
      final span = tester.widget<RichText>(_details).text as TextSpan;
      TextSpan? duration;
      span.visitChildren((child) {
        if (child is TextSpan && child.text == '1 day') duration = child;
        return true;
      });
      expect(duration, isNotNull);
      expect(duration!.style?.fontWeight, FontWeight.w700);
    });

    testWidgets('an allocation shows its balance at the right of the details', (
      tester,
    ) async {
      await tester.pumpWidget(_card(date: null, balance: '(0.0/0.0)'));

      final balance = tester.getRect(find.text('(0.0/0.0)'));
      final pill = tester.getRect(find.text('To Approve'));
      final details = tester.getRect(_details);
      // Beyond the details, and under the pill.
      expect(balance.left, greaterThanOrEqualTo(details.right));
      expect(balance.top, greaterThan(pill.bottom));
    });

    testWidgets('a time off has no balance', (tester) async {
      await tester.pumpWidget(_card());

      expect(find.textContaining('(0.0'), findsNothing);
    });

    testWidgets('sets the reason across the full width, under the photo row', (
      tester,
    ) async {
      await tester.pumpWidget(_card());

      final reason = tester.getRect(
        find.textContaining('Reason:', findRichText: true),
      );
      final photo = tester.getRect(_avatar);
      expect(reason.left, photo.left);
      expect(reason.top, greaterThanOrEqualTo(photo.bottom));
    });

    testWidgets('sets the reason in semi-bold, not the light weight it had', (
      tester,
    ) async {
      await tester.pumpWidget(_card());

      final reason = tester.widget<RichText>(
        find.textContaining('Reason:', findRichText: true),
      );
      expect((reason.text as TextSpan).style?.fontWeight, FontWeight.w600);
      expect(
        find.text(
          'Reason: Personal medical appointment (doctor).',
          findRichText: true,
        ),
        findsOneWidget,
      );
    });

    testWidgets('sets the reason at 13 — larger than the 11 it was', (
      tester,
    ) async {
      await tester.pumpWidget(_card());

      final reason = tester.widget<RichText>(
        find.textContaining('Reason:', findRichText: true),
      );
      final size = (reason.text as TextSpan).style?.fontSize;
      expect(size, WidgetTimeOffCard.reasonFontSize);
      expect(size, 13);
    });

    testWidgets('a long reason wraps to more lines without overflowing', (
      tester,
    ) async {
      tester.view.physicalSize = const Size(360, 700);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);

      await tester.pumpWidget(
        _card(
          reason:
              'Attending a family wedding out of town, so travelling the day '
              'before and returning the day after it',
        ),
      );

      expect(tester.takeException(), isNull);
      expect(
        find.textContaining('Reason:', findRichText: true),
        findsOneWidget,
      );
    });

    testWidgets('a request with no reason leaves the Reason line out', (
      tester,
    ) async {
      await tester.pumpWidget(_card(reason: ''));

      expect(find.textContaining('Reason', findRichText: true), findsNothing);
    });
  });

  group('the buttons', () {
    testWidgets('are two equal buttons, 31 tall, 8 apart, filling the width', (
      tester,
    ) async {
      await tester.pumpWidget(_card());

      expect(find.text('Refuse'), findsOneWidget);
      expect(find.text('Approve'), findsOneWidget);

      final refuse = tester.getRect(find.byType(OutlinedButton));
      final approve = tester.getRect(find.byType(ElevatedButton));
      final photo = tester.getRect(_avatar);

      expect(refuse.height, WidgetTimeOffCard.buttonHeight);
      expect(approve.height, WidgetTimeOffCard.buttonHeight);
      expect(refuse.width, approve.width);
      expect(approve.left - refuse.right, WidgetTimeOffCard.buttonSpacing);
      // Flush with the photo at the left.
      expect(refuse.left, photo.left);
    });

    testWidgets('Refuse is outlined, Approve filled — Approve in bold', (
      tester,
    ) async {
      await tester.pumpWidget(_card());

      expect(
        tester.widget<Text>(find.text('Approve')).style?.fontWeight,
        FontWeight.w700,
      );
      expect(
        tester.widget<Text>(find.text('Refuse')).style?.fontWeight,
        FontWeight.w600,
      );
      final shape =
          tester
                  .widget<ElevatedButton>(find.byType(ElevatedButton))
                  .style!
                  .shape!
                  .resolve({})
              as RoundedRectangleBorder;
      expect(
        shape.borderRadius,
        BorderRadius.circular(WidgetTimeOffCard.buttonRadius),
      );
    });

    testWidgets('an approved request has no buttons and a tight bottom', (
      tester,
    ) async {
      await tester.pumpWidget(_card(status: 'Approved', state: 'validate'));

      expect(find.byType(OutlinedButton), findsNothing);
      expect(find.byType(ElevatedButton), findsNothing);
      final card = tester.getRect(find.byType(WidgetTimeOffCard));
      final reason = tester.getRect(
        find.textContaining('Reason', findRichText: true),
      );
      expect(card.bottom - reason.bottom, lessThanOrEqualTo(16));
    });
  });

  testWidgets('is compact — about 122 tall with its reason and buttons', (
    tester,
  ) async {
    await tester.pumpWidget(_card());

    final height = tester.getRect(find.byType(WidgetTimeOffCard)).height;
    // 12 + photo 40 + 4 + a line + 8 + 31 + 12 (the test font's lines are a
    // little taller than the real one's).
    expect(height, inInclusiveRange(110, 140));
  });

  testWidgets('a long name and a narrow screen do not overflow', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(300, 600);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(
      _card(name: 'Bartholomew Maximilian Featherstonehaugh-Cholmondeley III'),
    );

    expect(tester.takeException(), isNull);
  });
}
