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

    expect(find.text('Today'), findsOneWidget);
  });

  testWidgets('event route passes event ID to detail placeholder', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        initialRoute: AppRoutes.eventDetail('battle-of-bosworth-field-1485'),
        onGenerateRoute: const AppRouter().onGenerateRoute,
      ),
    );

    expect(find.text('Event: battle-of-bosworth-field-1485'), findsOneWidget);
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
