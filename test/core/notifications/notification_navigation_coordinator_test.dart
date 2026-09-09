import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:on_this_day_mobile/core/config/timezone_provider.dart';
import 'package:on_this_day_mobile/core/navigation/app_router.dart';
import 'package:on_this_day_mobile/core/notifications/notification_navigation_coordinator.dart';
import 'package:on_this_day_mobile/core/notifications/notification_service.dart';
import 'package:on_this_day_mobile/features/on_this_day/data/fake_on_this_day_repository.dart';
import 'package:on_this_day_mobile/main.dart';

void main() {
  testWidgets('notification tap opens and loads the referenced event', (
    WidgetTester tester,
  ) async {
    final navigatorKey = GlobalKey<NavigatorState>();
    final coordinator = NotificationNavigationCoordinator(
      navigatorKey: navigatorKey,
    );
    final taps = StreamController<NotificationTap>();
    addTearDown(() async {
      await coordinator.dispose();
      await taps.close();
    });

    await tester.pumpWidget(
      OnThisDayApp(
        initialRoute: '/notification-test-host',
        navigatorKey: navigatorKey,
        router: AppRouter(
          repository: FakeOnThisDayRepository(),
          timezoneProvider: const _FixedTimezoneProvider(),
        ),
      ),
    );
    await coordinator.start(taps.stream);

    taps.add(const NotificationTap(eventId: 'loch-ness-monster-columba-565'));
    await tester.pump();
    await tester.pump();

    expect(
      find.text('Saint Columba reports seeing a monster in Loch Ness'),
      findsOneWidget,
    );
  });
}

class _FixedTimezoneProvider implements TimezoneProvider {
  const _FixedTimezoneProvider();

  @override
  Future<String> currentTimezone() async => 'Etc/UTC';
}
