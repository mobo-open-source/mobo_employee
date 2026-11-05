import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mobo_employees/features/manager/manager_attendance/widgets/attendance_card.dart';
import 'package:mobo_employees/shared/widgets/cards/group_tile_card.dart';
import 'package:mobo_employees/shared/widgets/filters/filter_status_row.dart';

Widget _app(Widget child, {Brightness brightness = Brightness.light}) {
  return MaterialApp(
    theme: ThemeData(brightness: brightness),
    home: Scaffold(
      body: Padding(padding: const EdgeInsets.all(16), child: child),
    ),
  );
}

/// The fill of the capsule that holds [text].
Color? _capsuleFill(WidgetTester tester, String text) {
  final container = tester.widget<Container>(
    find.ancestor(of: find.text(text), matching: find.byType(Container)).first,
  );
  return (container.decoration as BoxDecoration?)?.color;
}

Widget _statusRow({required bool isDark, int filters = 1, String? groupBy}) {
  return _app(
    FilterStatusRow(
      filterCount: filters,
      groupByLabel: groupBy,
      isDark: isDark,
      paginationText: '1-14/14',
      canPrev: false,
      canNext: false,
      onPrev: () {},
      onNext: () {},
      showPagination: false,
    ),
    brightness: isDark ? Brightness.dark : Brightness.light,
  );
}

void main() {
  group('AttendanceCard', () {
    testWidgets('shows the record the way a Sales list card does', (
      tester,
    ) async {
      await tester.pumpWidget(
        _app(
          const AttendanceCard(
            employee: 'Mitchell Admin',
            date: 'Nov 05, 2026',
            checkIn: '09:05 AM',
            checkOut: '06:10 PM',
            worked: '09:05',
            isCheckedIn: false,
          ),
        ),
      );

      expect(find.text('Mitchell Admin'), findsOneWidget);
      expect(find.text('Nov 05, 2026'), findsOneWidget);
      expect(find.text('Check In: 09:05 AM'), findsOneWidget);
      expect(find.text('Check Out: 06:10 PM'), findsOneWidget);
      expect(find.text('Worked Hours'), findsOneWidget);
      expect(find.text('09:05'), findsOneWidget);
      expect(find.text('Checked Out'), findsOneWidget);
    });

    testWidgets('an open attendance reads Checked In', (tester) async {
      await tester.pumpWidget(
        _app(
          const AttendanceCard(
            employee: 'Mitchell Admin',
            date: 'Nov 05, 2026',
            checkIn: '12:58 PM',
            checkOut: '-',
            worked: '00:00',
            isCheckedIn: true,
          ),
        ),
      );

      expect(find.text('Checked In'), findsOneWidget);
      expect(find.text('Checked Out'), findsNothing);
    });

    testWidgets('an overnight shift names the check-out day', (tester) async {
      await tester.pumpWidget(
        _app(
          const AttendanceCard(
            employee: 'Mitchell Admin',
            date: 'Nov 05, 2026',
            checkIn: '10:00 PM',
            checkOut: '06:00 AM',
            checkOutDate: 'Nov 06',
            worked: '08:00',
            isCheckedIn: false,
          ),
        ),
      );

      expect(find.text('Check Out: 06:00 AM (Nov 06)'), findsOneWidget);
    });

    testWidgets('a long name on a narrow screen does not overflow', (
      tester,
    ) async {
      tester.view.physicalSize = const Size(280, 600);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);

      await tester.pumpWidget(
        _app(
          const AttendanceCard(
            employee:
                'Bartholomew Maximilian Featherstonehaugh-Cholmondeley III',
            date: 'Nov 05, 2026',
            checkIn: '10:00 PM',
            checkOut: '06:00 AM',
            checkOutDate: 'Nov 06',
            worked: '08:00',
            isCheckedIn: false,
          ),
        ),
      );

      expect(tester.takeException(), isNull);
    });
  });

  group('GroupTileCard', () {
    testWidgets('shows the records only while expanded', (tester) async {
      var expanded = false;
      await tester.pumpWidget(
        StatefulBuilder(
          builder: (context, setState) => _app(
            GroupTileCard(
              title: 'October 2026',
              subtitle: '3 records',
              isExpanded: expanded,
              onToggle: () => setState(() => expanded = !expanded),
              body: const Text('the records'),
            ),
          ),
        ),
      );

      expect(find.text('October 2026'), findsOneWidget);
      expect(find.text('3 records'), findsOneWidget);
      expect(find.text('the records'), findsNothing);
      expect(find.byIcon(Icons.expand_more), findsOneWidget);

      await tester.tap(find.text('October 2026'));
      await tester.pump();

      expect(find.text('the records'), findsOneWidget);
      expect(find.byIcon(Icons.expand_less), findsOneWidget);
      // Sales' tile has no rule between the header and the records.
      expect(find.byType(Divider), findsNothing);
    });
  });

  group('filter capsules', () {
    testWidgets('the Active capsule is solid black, white text', (
      tester,
    ) async {
      await tester.pumpWidget(_statusRow(isDark: false));

      expect(_capsuleFill(tester, 'Active'), Colors.black);
      expect(tester.widget<Text>(find.text('Active')).style?.color, Colors.white);
    });

    testWidgets('in dark mode it inverts to white with black text', (
      tester,
    ) async {
      await tester.pumpWidget(_statusRow(isDark: true));

      expect(_capsuleFill(tester, 'Active'), Colors.white);
      expect(tester.widget<Text>(find.text('Active')).style?.color, Colors.black);
    });

    testWidgets('the Group By capsule is the same black / white', (
      tester,
    ) async {
      await tester.pumpWidget(_statusRow(isDark: false, groupBy: 'Month'));
      expect(_capsuleFill(tester, 'Month'), Colors.black);

      await tester.pumpWidget(_statusRow(isDark: true, groupBy: 'Month'));
      // MaterialApp animates a theme change; let it land before reading it.
      await tester.pumpAndSettle();
      expect(_capsuleFill(tester, 'Month'), Colors.white);
    });
  });
}
