import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:on_this_day_mobile/core/navigation/app_router.dart';
import 'package:on_this_day_mobile/core/navigation/app_routes.dart';
import 'package:on_this_day_mobile/main.dart';

void main() {
  test('builds event detail route names', () {
    expect(
      AppRoutes.eventDetail('battle-of-bosworth-field-1485'),
      '/events/battle-of-bosworth-field-1485',
    );
  });

  testWidgets('normal launch starts at today route', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(const OnThisDayApp());

    expect(find.text('On This Day'), findsOneWidget);
    expect(find.text("Loading today's history..."), findsOneWidget);
  });

  testWidgets('event route passes event ID to detail screen', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        initialRoute: AppRoutes.eventDetail('loch-ness-monster-columba-565'),
        onGenerateRoute: const AppRouter().onGenerateRoute,
      ),
    );

    expect(find.text('Loading event...'), findsOneWidget);

    await tester.pump();

    expect(
      find.text('Saint Columba reports seeing a monster in Loch Ness'),
      findsOneWidget,
    );
  });

  testWidgets('unknown route renders unavailable fallback', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        initialRoute: '/not-a-route',
        onGenerateRoute: const AppRouter().onGenerateRoute,
      ),
    );

    expect(find.text('Content unavailable'), findsOneWidget);
  });

  testWidgets('malformed event route renders unavailable fallback', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        initialRoute: '/events/foo/bar',
        onGenerateRoute: const AppRouter().onGenerateRoute,
      ),
    );

    expect(find.text('Content unavailable'), findsOneWidget);
  });
}
