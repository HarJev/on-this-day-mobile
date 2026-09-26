import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:on_this_day_mobile/core/config/timezone_provider.dart';
import 'package:on_this_day_mobile/core/navigation/app_router.dart';
import 'package:on_this_day_mobile/core/notifications/notification_navigation_coordinator.dart';
import 'package:on_this_day_mobile/core/notifications/notification_prompt_coordinator.dart';
import 'package:on_this_day_mobile/core/notifications/notification_service.dart';
import 'package:on_this_day_mobile/features/on_this_day/data/fake_on_this_day_repository.dart';
import 'package:on_this_day_mobile/features/on_this_day/presentation/event_detail_screen.dart';
import 'package:on_this_day_mobile/main.dart';

import 'support/notification_prompt_fakes.dart';

const _eventId = 'loch-ness-monster-columba-565';
const _eventTitle = 'Saint Columba reports seeing a monster in Loch Ness';

void main() {
  testWidgets(
    'cold start from a notification opens the event without prompting',
    (tester) async {
      final messaging = _FakeMessaging(
        initialMessageData: const {'eventId': _eventId},
      );
      final service = NotificationService(messaging: messaging);
      addTearDown(() async {
        await service.dispose();
        await messaging.dispose();
      });

      final startup = await service.start();
      final prompt = _promptFor(service);
      await tester.pumpWidget(
        OnThisDayApp(
          initialEventId: startup.initialEventId,
          router: _router(prompt),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text(_eventTitle), findsOneWidget);
      expect(messaging.requestCount, 0);

      // Today remains beneath the notified event.
      expect(find.byType(EventDetailScreen), findsOneWidget);
      await tester.tap(find.byTooltip('Back'));
      await tester.pumpAndSettle();
      expect(find.byType(EventDetailScreen), findsNothing);
      expect(find.text('Also on this day'), findsOneWidget);
      expect(messaging.requestCount, 0);
    },
  );

  testWidgets('warm notification tap still routes to Event Detail', (
    tester,
  ) async {
    final messaging = _FakeMessaging();
    final service = NotificationService(messaging: messaging);
    final navigatorKey = GlobalKey<NavigatorState>();
    final navigation = NotificationNavigationCoordinator(
      navigatorKey: navigatorKey,
    );
    addTearDown(() async {
      await navigation.dispose();
      await service.dispose();
      await messaging.dispose();
    });

    await service.start();
    await tester.pumpWidget(
      OnThisDayApp(
        navigatorKey: navigatorKey,
        router: _router(_promptFor(service)),
      ),
    );
    await navigation.start(service.notificationTaps);

    messaging.emitOpenedMessage(const {'eventId': _eventId});
    await tester.pumpAndSettle();

    expect(find.text(_eventTitle), findsOneWidget);
    expect(messaging.requestCount, 0);
  });
}

NotificationPromptCoordinator _promptFor(NotificationService service) {
  return NotificationPromptCoordinator(
    permissions: service,
    store: InMemoryPromptStore(),
    onAuthorized: (_) async {},
    deniedMayBeUnasked: false,
  );
}

AppRouter _router(NotificationPromptCoordinator prompt) {
  return AppRouter(
    repository: FakeOnThisDayRepository(),
    timezoneProvider: const _FixedTimezoneProvider(),
    notificationPrompt: prompt,
  );
}

class _FixedTimezoneProvider implements TimezoneProvider {
  const _FixedTimezoneProvider();

  @override
  Future<String> currentTimezone() async => 'Etc/UTC';
}

class _FakeMessaging implements NotificationMessaging {
  _FakeMessaging({this.initialMessageData});

  final Map<String, Object?>? initialMessageData;
  NotificationPermissionStatus status =
      NotificationPermissionStatus.notDetermined;
  int requestCount = 0;

  final StreamController<String> _refresh =
      StreamController<String>.broadcast();
  final StreamController<Map<String, Object?>> _opened =
      StreamController<Map<String, Object?>>.broadcast();

  @override
  Future<NotificationPermissionStatus> requestPermission() async {
    requestCount += 1;
    return status;
  }

  @override
  Future<NotificationPermissionStatus> getPermissionStatus() async => status;

  @override
  Future<String?> getToken() async => 'token';

  @override
  Stream<String> get onTokenRefresh => _refresh.stream;

  @override
  Future<Map<String, Object?>?> getInitialMessageData() async =>
      initialMessageData;

  @override
  Stream<Map<String, Object?>> get onMessageOpenedAppData => _opened.stream;

  void emitOpenedMessage(Map<String, Object?> data) => _opened.add(data);

  Future<void> dispose() async {
    await _refresh.close();
    await _opened.close();
  }
}
