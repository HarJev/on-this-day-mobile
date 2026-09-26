import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:on_this_day_mobile/core/api/api_client.dart';
import 'package:on_this_day_mobile/core/config/timezone_provider.dart';
import 'package:on_this_day_mobile/core/navigation/app_router.dart';
import 'package:on_this_day_mobile/core/notifications/device_platform_provider.dart';
import 'package:on_this_day_mobile/core/notifications/device_registration_client.dart';
import 'package:on_this_day_mobile/core/notifications/device_registration_coordinator.dart';
import 'package:on_this_day_mobile/core/notifications/notification_navigation_coordinator.dart';
import 'package:on_this_day_mobile/core/notifications/notification_prompt_coordinator.dart';
import 'package:on_this_day_mobile/core/notifications/notification_service.dart';
import 'package:on_this_day_mobile/features/on_this_day/data/fake_on_this_day_repository.dart';
import 'package:on_this_day_mobile/features/on_this_day/presentation/event_detail_screen.dart';
import 'package:on_this_day_mobile/features/on_this_day/presentation/widgets/featured_event_card.dart';
import 'package:on_this_day_mobile/features/on_this_day/presentation/widgets/notification_pre_prompt.dart';
import 'package:on_this_day_mobile/main.dart';

import 'support/notification_prompt_fakes.dart';

const _eventId = 'loch-ness-monster-columba-565';
const _eventTitle = 'Saint Columba reports seeing a monster in Loch Ness';

void main() {
  // Built inside each test so its futures belong to the widget test's zone.
  _App newApp() {
    final app = _App();
    addTearDown(app.dispose);
    return app;
  }

  testWidgets(
    'cold start from a notification opens the event without prompting',
    (tester) async {
      final app = newApp();
      app.messaging.initialMessageData = const {'eventId': _eventId};
      final startup = await app.start();

      await tester.pumpWidget(
        app.widget(initialEventId: startup.initialEventId),
      );
      await tester.pumpAndSettle();

      expect(find.text(_eventTitle), findsOneWidget);
      expect(app.messaging.requestCount, 0);

      // Today remains beneath the notified event.
      expect(find.byType(EventDetailScreen), findsOneWidget);
      await tester.tap(find.byTooltip('Back'));
      await tester.pumpAndSettle();
      expect(find.byType(EventDetailScreen), findsNothing);
      expect(find.text('Also on this day'), findsOneWidget);
      expect(app.messaging.requestCount, 0);
      expect(app.requests, isEmpty);
    },
  );

  testWidgets('warm notification tap still routes to Event Detail', (
    tester,
  ) async {
    final app = newApp();
    await app.start();
    final navigatorKey = GlobalKey<NavigatorState>();
    final navigation = NotificationNavigationCoordinator(
      navigatorKey: navigatorKey,
    );
    addTearDown(navigation.dispose);
    await tester.pumpWidget(app.widget(navigatorKey: navigatorKey));
    await navigation.start(app.service.notificationTaps);

    app.messaging.emitOpenedMessage(const {'eventId': _eventId});
    await tester.pumpAndSettle();

    expect(find.text(_eventTitle), findsOneWidget);
    expect(app.messaging.requestCount, 0);
  });

  testWidgets(
    'Today -> Event Detail -> invitation: "Not now" never requests permission',
    (tester) async {
      final app = newApp();
      await app.start();
      await tester.pumpWidget(app.widget());
      await tester.pumpAndSettle();
      expect(app.messaging.requestCount, 0);

      await _openFeaturedEventAndScrollToInvitation(tester);
      await _tapAction(tester, NotificationPrePrompt.declineLabel);
      await tester.pumpAndSettle();

      expect(find.byKey(const Key('notification-pre-prompt')), findsNothing);
      expect(app.messaging.requestCount, 0);
      expect(app.requests, isEmpty);
      expect(app.promptStore.record!.declineCount, 1);
    },
  );

  testWidgets(
    'Today -> Event Detail -> invitation: only "Turn on" requests permission, '
    'then the device registers',
    (tester) async {
      final app = newApp();
      await app.start();
      await tester.pumpWidget(app.widget());
      await tester.pumpAndSettle();
      expect(app.messaging.requestCount, 0);
      expect(app.requests, isEmpty);

      await _openFeaturedEventAndScrollToInvitation(tester);
      expect(app.messaging.requestCount, 0);

      await _tapAction(tester, NotificationPrePrompt.enableLabel);
      await tester.pumpAndSettle();

      expect(app.messaging.requestCount, 1);
      expect(find.text('Notifications are on.'), findsOneWidget);
      expect(app.requests, ['POST e2e-token']);
      expect(app.tokenStore.token, 'e2e-token');
      expect(app.promptStore.record!.requested, isTrue);
    },
  );
}

Future<void> _openFeaturedEventAndScrollToInvitation(
  WidgetTester tester,
) async {
  await tester.tap(find.byType(FeaturedEventCard));
  await tester.pumpAndSettle();
  expect(find.byType(EventDetailScreen), findsOneWidget);

  final enable = find.text(NotificationPrePrompt.enableLabel);
  var drags = 0;
  while (enable.evaluate().isEmpty || !_fullyOnScreen(tester, enable)) {
    expect(drags, lessThan(20), reason: 'invitation never became reachable');
    await tester.drag(find.byType(ListView).last, const Offset(0, -150));
    await tester.pumpAndSettle();
    drags++;
  }
}

bool _fullyOnScreen(WidgetTester tester, Finder finder) {
  final rect = tester.getRect(finder.first);
  final screen =
      Offset.zero & tester.view.physicalSize / tester.view.devicePixelRatio;
  return screen.contains(rect.topLeft) && screen.contains(rect.bottomRight);
}

Future<void> _tapAction(WidgetTester tester, String label) async {
  final action = find.text(label);
  await tester.ensureVisible(action);
  await tester.pumpAndSettle();
  await tester.tap(action);
}

/// Wires the notification pieces the way `main.dart` does, with fakes only at
/// the platform (Firebase) and network edges.
class _App {
  _App() {
    service = NotificationService(messaging: messaging);
    registration = DeviceRegistrationCoordinator(
      client: DeviceRegistrationClient(
        apiClient: ApiClient(
          baseUrl: Uri.parse('http://127.0.0.1:3000'),
          httpClient: MockClient((request) async {
            final token = RegExp(
              r'"token":"([^"]+)"',
            ).firstMatch(request.body)?[1];
            requests.add('${request.method} ${token ?? request.url.path}');
            return http.Response(
              request.method == 'POST'
                  ? '{"registered":true}'
                  : '{"deleted":true}',
              200,
            );
          }),
        ),
      ),
      timezoneProvider: const _FixedTimezoneProvider(),
      platformProvider: const PlatformDevicePlatformProvider(
        operatingSystem: 'ios',
      ),
      notificationService: service,
      registeredTokens: tokenStore,
    );
    prompt = NotificationPromptCoordinator(
      permissions: service,
      store: promptStore,
      onAuthorized: registration.registerAfterAuthorization,
      deniedMayBeUnasked: false,
    );
  }

  final _FakeMessaging messaging = _FakeMessaging();
  final InMemoryPromptStore promptStore = InMemoryPromptStore();
  final InMemoryRegisteredTokenStore tokenStore =
      InMemoryRegisteredTokenStore();
  final List<String> requests = [];
  late final NotificationService service;
  late final DeviceRegistrationCoordinator registration;
  late final NotificationPromptCoordinator prompt;

  Future<NotificationStartupState> start() async {
    final startup = await service.start();
    await registration.start(startup);
    return startup;
  }

  Widget widget({
    String? initialEventId,
    GlobalKey<NavigatorState>? navigatorKey,
  }) {
    return OnThisDayApp(
      initialEventId: initialEventId,
      navigatorKey: navigatorKey,
      router: AppRouter(
        repository: FakeOnThisDayRepository(),
        timezoneProvider: const _FixedTimezoneProvider(),
        navigatorKey: navigatorKey,
        notificationPrompt: prompt,
      ),
    );
  }

  Future<void> dispose() async {
    await registration.dispose();
    await service.dispose();
    await messaging.dispose();
  }
}

class _FixedTimezoneProvider implements TimezoneProvider {
  const _FixedTimezoneProvider();

  @override
  Future<String> currentTimezone() async => 'Etc/UTC';
}

class _FakeMessaging implements NotificationMessaging {
  Map<String, Object?>? initialMessageData;
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
    status = NotificationPermissionStatus.authorized;
    return status;
  }

  @override
  Future<NotificationPermissionStatus> getPermissionStatus() async => status;

  @override
  Future<String?> getToken() async => 'e2e-token';

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
