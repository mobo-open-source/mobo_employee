import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mobo_employees/core/const/all_design.dart';
import 'package:mobo_employees/features/manager/manager_employees/widgets/widget_employee_card.dart';
import 'package:mobo_employees/features/manager/manager_employees/widgets/widget_employee_card_shimmer.dart';

/// The card's hairline border, which insets its content.
const double _border = 0.5;

Widget _card({String job = 'Consultant', String name = 'Abigail Peterson'}) {
  return MaterialApp(
    home: Scaffold(
      // Top-aligned, as in the list: a Scaffold body is tight, which would
      // stretch the card to the whole screen.
      body: Align(
        alignment: Alignment.topCenter,
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: WidgetEmployeeCard(
            employeeName: name,
            employeeJob: job,
            employeePhone: '(555) 123-4567',
            employeeEmail: 'abigail.peterson@example.com',
            child: const SizedBox(
              width: WidgetEmployeeCard.avatarSize,
              height: WidgetEmployeeCard.avatarSize,
            ),
          ),
        ),
      ),
    ),
  );
}

/// The badge behind [job]: its fill and its text colour.
({Color? fill, Color? text}) _badge(WidgetTester tester, String job) {
  final container = tester.widget<Container>(
    find.ancestor(of: find.text(job), matching: find.byType(Container)).first,
  );
  return (
    fill: (container.decoration as BoxDecoration).color,
    text: tester.widget<Text>(find.text(job)).style?.color,
  );
}

void main() {
  group('jobColor', () {
    test('a developer of any kind is blue', () {
      expect(
        WidgetEmployeeCard.jobColor('Experienced Developer'),
        AppColors.Color0095FF,
      );
      expect(WidgetEmployeeCard.jobColor('Developer'), AppColors.Color0095FF);
      expect(
        WidgetEmployeeCard.jobColor('Senior DEVELOPER'),
        AppColors.Color0095FF,
      );
    });

    test('every other title — or none — is green', () {
      expect(WidgetEmployeeCard.jobColor('Consultant'), AppColors.color65BA68);
      expect(
        WidgetEmployeeCard.jobColor('Chief Executive Officer'),
        AppColors.color65BA68,
      );
      expect(WidgetEmployeeCard.jobColor('-'), AppColors.color65BA68);
      expect(WidgetEmployeeCard.jobColor(null), AppColors.color65BA68);
    });
  });

  group('WidgetEmployeeCard', () {
    testWidgets('an Experienced Developer gets the blue badge', (tester) async {
      await tester.pumpWidget(_card(job: 'Experienced Developer'));

      final badge = _badge(tester, 'Experienced Developer');
      // Pale blue with dark blue text — as a pending status on the Approvals
      // cards.
      expect(badge.text, const Color(0xFF0E5794));
      expect(badge.fill, const Color(0xFFDAEEFE));
    });

    testWidgets('a Consultant keeps the green badge', (tester) async {
      await tester.pumpWidget(_card(job: 'Consultant'));

      final badge = _badge(tester, 'Consultant');
      // Pale green with dark green text.
      expect(badge.text, const Color(0xFF186C1B));
      expect(badge.fill, const Color(0xFFE3F2E3));
    });

    testWidgets('sets the role in bold', (tester) async {
      for (final job in ['Experienced Developer', 'Consultant']) {
        await tester.pumpWidget(_card(job: job));
        expect(
          tester.widget<Text>(find.text(job)).style?.fontWeight,
          FontWeight.w700,
          reason: job,
        );
      }
    });

    testWidgets('the role text is darker than the hue it used to be', (
      tester,
    ) async {
      await tester.pumpWidget(_card(job: 'Consultant'));

      final text = tester.widget<Text>(find.text('Consultant')).style!.color!;
      // Darker than the bright green it was (lower lightness), not equal to it.
      expect(text, isNot(AppColors.color65BA68));
      expect(
        HSLColor.fromColor(text).lightness,
        lessThan(HSLColor.fromColor(AppColors.color65BA68).lightness - 0.2),
      );
    });

    test('dark mode is the translucent-white pill with white text', () {
      final colors = WidgetEmployeeCard.rolePillColors('Consultant', true);
      expect(colors.fill, Colors.white.withValues(alpha: 0.15));
      expect(colors.text, Colors.white);
    });

    testWidgets('shows the name, phone and email', (tester) async {
      await tester.pumpWidget(_card());

      expect(find.text('Abigail Peterson'), findsOneWidget);
      expect(find.text('(555) 123-4567'), findsOneWidget);
      expect(find.text('abigail.peterson@example.com'), findsOneWidget);
    });

    testWidgets('a long name and title on a narrow screen do not overflow', (
      tester,
    ) async {
      tester.view.physicalSize = const Size(300, 600);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);

      await tester.pumpWidget(
        _card(
          job: 'Chief Executive Officer and Head of Everything Else',
          name: 'Bartholomew Maximilian Featherstonehaugh-Cholmondeley III',
        ),
      );

      expect(tester.takeException(), isNull);
    });

    // The card's 0.5px border insets its content by that much more than the
    // padding itself (a bordered Container pads its child by the border).
    testWidgets('the content sits 12 in from the sides, 16 above and below', (
      tester,
    ) async {
      await tester.pumpWidget(_card());

      final card = find.byType(WidgetEmployeeCard);
      final avatar = find.byWidgetPredicate(
        (w) =>
            w is SizedBox &&
            w.width == WidgetEmployeeCard.avatarSize &&
            w.height == WidgetEmployeeCard.avatarSize,
      );
      final cardRect = tester.getRect(card);
      final avatarRect = tester.getRect(avatar);

      expect(avatarRect.left - cardRect.left, _border + 12);
      expect(avatarRect.top - cardRect.top, _border + 16);
      expect(
        cardRect.bottom -
            tester.getRect(find.text('abigail.peterson@example.com')).bottom,
        greaterThanOrEqualTo(16),
      );
    });
  });

  group('the avatar beside the text', () {
    /// The avatar and the name / phone / email column, as laid out.
    ({Rect avatar, Rect text, Rect card}) rects(WidgetTester tester) {
      final card = find.byType(WidgetEmployeeCard);
      return (
        avatar: tester.getRect(
          find.byWidgetPredicate(
            (w) =>
                w is SizedBox &&
                w.width == WidgetEmployeeCard.avatarSize &&
                w.height == WidgetEmployeeCard.avatarSize,
          ),
        ),
        // The card's one Column is its text.
        text: tester.getRect(
          find.descendant(of: card, matching: find.byType(Column)),
        ),
        card: tester.getRect(card),
      );
    }

    testWidgets('runs the whole height of the text: name down to email', (
      tester,
    ) async {
      await tester.pumpWidget(_card());

      final r = rects(tester);
      expect(r.avatar.top, r.text.top);
      expect(r.avatar.bottom, r.text.bottom);
      expect(r.avatar.height, r.text.height);
    });

    testWidgets('is bigger than the 52 it was, and square', (tester) async {
      await tester.pumpWidget(_card());

      final r = rects(tester);
      expect(r.avatar.height, greaterThan(52));
      expect(r.avatar.width, r.avatar.height);
    });

    test('the text block is its three fixed lines and two gaps', () {
      expect(
        WidgetEmployeeCard.textBlockHeight,
        WidgetEmployeeCard.nameLineHeight +
            2 * WidgetEmployeeCard.detailLineHeight +
            2 * WidgetEmployeeCard.lineGap,
      );
      expect(WidgetEmployeeCard.avatarSize, WidgetEmployeeCard.textBlockHeight);
    });

    testWidgets('keeps the card the 91px of the design', (tester) async {
      await tester.pumpWidget(_card());

      // 16 above and below the 58px block, and the hairline border.
      expect(rects(tester).card.height, 16 + 58 + 16 + 2 * _border);
    });

    testWidgets('a different title or a long name does not change the height', (
      tester,
    ) async {
      await tester.pumpWidget(_card());
      final plain = rects(tester);

      await tester.pumpWidget(
        _card(
          job: 'Chief Executive Officer and Head of Everything Else',
          name: 'Bartholomew Maximilian Featherstonehaugh-Cholmondeley III',
        ),
      );
      final long = rects(tester);

      expect(long.card.height, plain.card.height);
      expect(long.avatar.height, plain.avatar.height);
    });

    testWidgets('the loading placeholder is the same height as the card', (
      tester,
    ) async {
      await tester.pumpWidget(_card());
      final loaded = tester.getSize(find.byType(WidgetEmployeeCard)).height;

      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: Align(
              alignment: Alignment.topCenter,
              child: Padding(
                padding: EdgeInsets.all(16),
                child: WidgetEmployeeCardShimmer(),
              ),
            ),
          ),
        ),
      );
      final loading = tester
          .getSize(find.byType(WidgetEmployeeCardShimmer))
          .height;

      expect(loading, loaded);
    });
  });

  testWidgets('the loading placeholder uses the card padding and avatar', (
    tester,
  ) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: Padding(
            padding: EdgeInsets.all(16),
            child: WidgetEmployeeCardShimmer(),
          ),
        ),
      ),
    );

    final avatar = tester.getRect(
      find.byWidgetPredicate(
        (w) =>
            w is Container &&
            w.constraints?.maxWidth == WidgetEmployeeCard.avatarSize,
      ),
    );
    final card = tester.getRect(find.byType(WidgetEmployeeCardShimmer));
    expect(avatar.left - card.left, _border + 12);
    expect(avatar.top - card.top, _border + 16);
  });
}
