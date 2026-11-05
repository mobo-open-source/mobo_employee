import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hugeicons/hugeicons.dart';
import 'package:mobo_employees/shared/widgets/pagination/pagination_controls.dart';

Widget _controls({
  required bool canGoToPreviousPage,
  required bool canGoToNextPage,
  String paginationText = '21-40/200',
  VoidCallback? onPreviousPage,
  VoidCallback? onNextPage,
}) {
  return MaterialApp(
    home: Scaffold(
      body: Center(
        child: PaginationControls(
          canGoToPreviousPage: canGoToPreviousPage,
          canGoToNextPage: canGoToNextPage,
          onPreviousPage: onPreviousPage ?? () {},
          onNextPage: onNextPage ?? () {},
          paginationText: paginationText,
          isDark: false,
        ),
      ),
    ),
  );
}

Finder _arrow(List<List<dynamic>> icon) => find.byWidgetPredicate(
  (widget) => widget is HugeIcon && widget.icon == icon,
);

void main() {
  testWidgets('both arrows work when there are pages either way', (
    tester,
  ) async {
    var previous = 0;
    var next = 0;
    await tester.pumpWidget(
      _controls(
        canGoToPreviousPage: true,
        canGoToNextPage: true,
        onPreviousPage: () => previous++,
        onNextPage: () => next++,
      ),
    );

    expect(find.text('21-40/200'), findsOneWidget);
    await tester.tap(_arrow(HugeIcons.strokeRoundedArrowLeft01));
    await tester.tap(_arrow(HugeIcons.strokeRoundedArrowRight01));

    expect(previous, 1);
    expect(next, 1);
  });

  testWidgets('an unusable arrow is hidden but keeps its slot', (
    tester,
  ) async {
    await tester.pumpWidget(
      _controls(canGoToPreviousPage: true, canGoToNextPage: true),
    );
    final nextWhenBothShown = tester.getCenter(
      _arrow(HugeIcons.strokeRoundedArrowRight01),
    );

    await tester.pumpWidget(
      _controls(canGoToPreviousPage: false, canGoToNextPage: true),
    );

    final previous = tester.widget<Visibility>(
      find.ancestor(
        of: _arrow(HugeIcons.strokeRoundedArrowLeft01),
        matching: find.byType(Visibility),
      ),
    );
    expect(previous.visible, isFalse);
    expect(
      tester.getCenter(_arrow(HugeIcons.strokeRoundedArrowRight01)),
      nextWhenBothShown,
    );
  });

  testWidgets('a single page keeps its count but shows no arrows', (
    tester,
  ) async {
    await tester.pumpWidget(
      _controls(
        canGoToPreviousPage: false,
        canGoToNextPage: false,
        paginationText: '1-5/5',
      ),
    );

    expect(find.text('1-5/5'), findsOneWidget);
    expect(_arrow(HugeIcons.strokeRoundedArrowLeft01), findsNothing);
    expect(_arrow(HugeIcons.strokeRoundedArrowRight01), findsNothing);
  });
}
