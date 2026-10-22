import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mobo_employees/core/services/connectivity_service.dart';
import 'package:mobo_employees/shared/widgets/connection_status_widget.dart';

Widget _host(Widget child) => MaterialApp(home: Scaffold(body: child));

void main() {
  testWidgets('shows the offline state for NoInternetException', (
    tester,
  ) async {
    await tester.pumpWidget(
      _host(ConnectionStatusWidget(error: NoInternetException('offline'))),
    );

    expect(find.text("You're Offline"), findsOneWidget);
    expect(find.text('Retry'), findsNothing);
  });

  testWidgets('shows the server unreachable state for a refused connection', (
    tester,
  ) async {
    await tester.pumpWidget(
      _host(
        ConnectionStatusWidget(error: ServerUnreachableException('refused')),
      ),
    );

    expect(find.text('Server Unreachable'), findsOneWidget);
  });

  testWidgets('shows a generic state for other errors', (tester) async {
    await tester.pumpWidget(
      _host(ConnectionStatusWidget(error: StateError('boom'))),
    );

    expect(find.text('Something Went Wrong'), findsOneWidget);
    expect(
      find.text("We couldn't load this page. Please try again."),
      findsOneWidget,
    );
  });

  testWidgets('Retry calls onRetry', (tester) async {
    var retries = 0;
    await tester.pumpWidget(
      _host(
        ConnectionStatusWidget(
          error: StateError('boom'),
          onRetry: () async => retries++,
        ),
      ),
    );

    await tester.tap(find.text('Retry'));
    await tester.pumpAndSettle();

    expect(retries, 1);
  });
}
