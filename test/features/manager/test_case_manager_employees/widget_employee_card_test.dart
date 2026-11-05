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
      body: Padding(
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
      expect(badge.text, AppColors.Color0095FF);
      expect(badge.fill, AppColors.Color0095FF.withValues(alpha: 0.12));
    });

    testWidgets('a Consultant keeps the green badge', (tester) async {
      await tester.pumpWidget(_card(job: 'Consultant'));

      final badge = _badge(tester, 'Consultant');
      expect(badge.text, AppColors.color65BA68);
      expect(badge.fill, AppColors.color65BA68.withValues(alpha: 0.12));
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
