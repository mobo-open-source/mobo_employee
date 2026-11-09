import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mobo_employees/core/const/all_design.dart';
import 'package:mobo_employees/widgets/shimmer_widgets/shimmer_dashboard.dart';
import 'package:mobo_employees/widgets/widget_checkin_card.dart';
import 'package:mobo_employees/widgets/widget_costoverviewcard.dart';
import 'package:mobo_employees/widgets/widget_recentActivity.dart';

void main() {
  group('dark mode', () {
    test('the dashboard cards share one card grey — the events app\'s', () {
      final checkIn = WidgetCheckInCard.decoration(true).color;
      final overview = WidgetQuickOverview.decoration(true).color;
      final activity = WidgetRecentActivity.decoration(true).color;

      expect(checkIn, Colors.grey[850]);
      expect(overview, checkIn);
      expect(activity, checkIn);
    });

    test('the check-in card is no longer the lighter #424242', () {
      expect(
        WidgetCheckInCard.decoration(true).color,
        isNot(AppColors.greyShade800Color),
      );
    });

    test('its outline is a faint hairline, not a bright #616161 ring', () {
      final border = WidgetCheckInCard.decoration(true).border! as Border;

      expect(border.top.color, isNot(AppColors.greyShade700Color));
      expect(border.top.color.a, lessThan(1.0));
    });
  });

  group('light mode (unchanged)', () {
    test('the check-in card is white with its pale grey outline', () {
      final decoration = WidgetCheckInCard.decoration(false);

      expect(decoration.color, Colors.white);
      expect((decoration.border! as Border).top.color, const Color(0xFFE0E0E0));
      expect(decoration.borderRadius, BorderRadius.circular(16));
    });
  });

  group('the caption under the figure', () {
    Widget card(String subtitle, {bool dark = false}) => MaterialApp(
      home: Scaffold(
        body: SizedBox(
          width: 180,
          height: WidgetQuickOverview.height,
          child: WidgetQuickOverview(
            count: '12',
            title: 'Employees',
            subtitle: subtitle,
            color: Colors.green,
            isDarkTheme: dark,
          ),
        ),
      ),
    );

    testWidgets('is semi-bold — Total Employees, Daily attendance, Leaves on '
        'today', (tester) async {
      for (final caption in [
        'Total Employees',
        'Daily attendance',
        'Leaves on today',
      ]) {
        await tester.pumpWidget(card(caption));
        expect(
          tester.widget<Text>(find.text(caption)).style?.fontWeight,
          FontWeight.w600,
          reason: caption,
        );
      }
    });

    testWidgets('keeps its size and grey, and is the same in dark mode', (
      tester,
    ) async {
      await tester.pumpWidget(card('Total Employees', dark: true));

      final style = tester.widget<Text>(find.text('Total Employees')).style!;
      expect(style.fontWeight, FontWeight.w600);
      expect(style.fontSize, 11);
      expect(style.color, Colors.grey[400]);
    });
  });

  testWidgets('the loading placeholder wears the same card', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: ThemeData(brightness: Brightness.dark),
        home: const Scaffold(body: DashboardShimmer(isDarkTheme: true)),
      ),
    );
    await tester.pump();

    expect(
      find.byWidgetPredicate(
        (w) =>
            w is Container &&
            w.decoration == WidgetCheckInCard.decoration(true),
      ),
      findsWidgets,
    );
  });
}
