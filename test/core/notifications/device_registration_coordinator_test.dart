import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:on_this_day_mobile/core/api/api_client.dart';
import 'package:on_this_day_mobile/core/config/timezone_provider.dart';
import 'package:on_this_day_mobile/core/notifications/device_platform_provider.dart';
import 'package:on_this_day_mobile/core/notifications/device_registration_client.dart';
import 'package:on_this_day_mobile/core/notifications/device_registration_coordinator.dart';
import 'package:on_this_day_mobile/core/notifications/notification_service.dart';

void main() {
  group('DeviceRegistrationCoordinator', () {
    test('registers the current token when already authorized', () async {
      final requests = <http.Request>[];
      final messaging = _FakeNotificationMessaging(token: 'startup-token');
      final coordinator = _coordinator(
        notificationService: NotificationService(messaging: messaging),
        httpClient: MockClient((request) async {
          requests.add(request);
          return http.Response('{"registered":true}', 200);
        }),
      );

      await coordinator.start(
        const NotificationStartupState(
          permissionStatus: NotificationPermissionStatus.authorized,
          initialEventId: null,
        ),
      );

      expect(messaging.permissionRequestCount, 0);
      expect(requests, hasLength(1));
      expect(requests.single.method, 'POST');
      expect(requests.single.body, contains('"token":"startup-token"'));
      expect(requests.single.body, contains('"platform":"ios"'));
      expect(requests.single.body, contains('"timezone":"America/Jamaica"'));
      expect(
        requests.single.body,
        contains('"notificationPermissionStatus":"authorized"'),
      );

      await coordinator.dispose();
      await messaging.dispose();
    });

    for (final status in [
      NotificationPermissionStatus.notDetermined,
      NotificationPermissionStatus.denied,
      NotificationPermissionStatus.permanentlyDenied,
    ]) {
      test(
        'does not fetch or register a token at startup when $status',
        () async {
          final requests = <http.Request>[];
          final messaging = _FakeNotificationMessaging(token: 'startup-token');
          final coordinator = _coordinator(
            notificationService: NotificationService(messaging: messaging),
            httpClient: MockClient((request) async {
              requests.add(request);
              return http.Response('{"registered":true}', 200);
            }),
          );

          await coordinator.start(
            NotificationStartupState(
              permissionStatus: status,
              initialEventId: null,
            ),
          );

          expect(messaging.tokenRequestCount, 0);
          expect(messaging.permissionRequestCount, 0);
          expect(requests, isEmpty);

          await coordinator.dispose();
          await messaging.dispose();
        },
      );
    }

    test('registers after authorization with the granted status', () async {
      final requests = <http.Request>[];
      final messaging = _FakeNotificationMessaging(token: 'new-token');
      final coordinator = _coordinator(
        notificationService: NotificationService(messaging: messaging),
        httpClient: MockClient((request) async {
          requests.add(request);
          return http.Response('{"registered":true}', 200);
        }),
      );
      await coordinator.start(
        const NotificationStartupState(
          permissionStatus: NotificationPermissionStatus.notDetermined,
          initialEventId: null,
        ),
      );

      await coordinator.registerAfterAuthorization(
        NotificationPermissionStatus.provisional,
      );

      expect(requests, hasLength(1));
      expect(requests.single.body, contains('"token":"new-token"'));
      expect(
        requests.single.body,
        contains('"notificationPermissionStatus":"provisional"'),
      );

      await coordinator.dispose();
      await messaging.dispose();
    });

    test('skips registration when no token is available yet', () async {
      final requests = <http.Request>[];
      final messaging = _FakeNotificationMessaging(token: null);
      final coordinator = _coordinator(
        notificationService: NotificationService(messaging: messaging),
        httpClient: MockClient((request) async {
          requests.add(request);
          return http.Response('{"registered":true}', 200);
        }),
      );

      await coordinator.registerAfterAuthorization(
        NotificationPermissionStatus.authorized,
      );

      expect(messaging.tokenRequestCount, 1);
      expect(requests, isEmpty);

      await coordinator.dispose();
      await messaging.dispose();
    });

    test('does not throw when registration fails', () async {
      final messaging = _FakeNotificationMessaging(token: 'startup-token');
      final coordinator = _coordinator(
        notificationService: NotificationService(messaging: messaging),
        httpClient: MockClient((_) async => throw Exception('offline')),
      );

      await coordinator.start(
        const NotificationStartupState(
          permissionStatus: NotificationPermissionStatus.authorized,
          initialEventId: null,
        ),
      );
      await coordinator.registerAfterAuthorization(
        NotificationPermissionStatus.authorized,
      );

      await coordinator.dispose();
      await messaging.dispose();
    });

    test(
      're-registers refreshed tokens with refreshed permission status',
      () async {
        final requests = <http.Request>[];
        final messaging = _FakeNotificationMessaging(
          permissionStatus: NotificationPermissionStatus.authorized,
          currentPermissionStatus: NotificationPermissionStatus.provisional,
        );
        final service = NotificationService(messaging: messaging);
        final coordinator = _coordinator(
          notificationService: service,
          httpClient: MockClient((request) async {
            requests.add(request);
            return http.Response('{"registered":true}', 200);
          }),
        );

        final startupState = await service.start();
        await coordinator.start(startupState);
        messaging.emitTokenRefresh('refresh-token');
        await Future<void>.delayed(Duration.zero);
        await Future<void>.delayed(Duration.zero);

        expect(requests, hasLength(1));
        expect(requests.single.body, contains('"token":"refresh-token"'));
        expect(
          requests.single.body,
          contains('"notificationPermissionStatus":"provisional"'),
        );
        // Once at startup (read only) and once to refresh on token rotation.
        expect(messaging.permissionStatusRequestCount, 2);
        expect(messaging.permissionRequestCount, 0);

        await coordinator.dispose();
        await service.dispose();
        await messaging.dispose();
      },
    );
  });
}

DeviceRegistrationCoordinator _coordinator({
  NotificationService? notificationService,
  http.Client? httpClient,
}) {
  final service =
      notificationService ??
      NotificationService(messaging: _FakeNotificationMessaging());

  return DeviceRegistrationCoordinator(
    client: DeviceRegistrationClient(
      apiClient: ApiClient(
        baseUrl: Uri.parse('http://127.0.0.1:3000'),
        httpClient:
            httpClient ??
            MockClient((_) async => http.Response('{"registered":true}', 200)),
      ),
    ),
    timezoneProvider: const _FakeTimezoneProvider(),
    platformProvider: const PlatformDevicePlatformProvider(
      operatingSystem: 'ios',
    ),
    notificationService: service,
  );
}

class _FakeTimezoneProvider implements TimezoneProvider {
  const _FakeTimezoneProvider();

  @override
  Future<String> currentTimezone() async {
    return 'America/Jamaica';
  }
}

class _FakeNotificationMessaging implements NotificationMessaging {
  _FakeNotificationMessaging({
    this.permissionStatus = NotificationPermissionStatus.authorized,
    this.currentPermissionStatus = NotificationPermissionStatus.authorized,
    this.token,
  });

  final NotificationPermissionStatus permissionStatus;
  final NotificationPermissionStatus currentPermissionStatus;
  final String? token;
  final StreamController<String> _tokenRefreshController =
      StreamController<String>.broadcast();
  final StreamController<Map<String, Object?>> _openedMessageController =
      StreamController<Map<String, Object?>>.broadcast();

  int permissionStatusRequestCount = 0;
  int permissionRequestCount = 0;
  int tokenRequestCount = 0;

  @override
  Future<NotificationPermissionStatus> requestPermission() async {
    permissionRequestCount += 1;
    return permissionStatus;
  }

  @override
  Future<NotificationPermissionStatus> getPermissionStatus() async {
    permissionStatusRequestCount += 1;
    return currentPermissionStatus;
  }

  @override
  Future<String?> getToken() async {
    tokenRequestCount += 1;
    return token;
  }

  @override
  Stream<String> get onTokenRefresh => _tokenRefreshController.stream;

  @override
  Future<Map<String, Object?>?> getInitialMessageData() async {
    return null;
  }

  @override
  Stream<Map<String, Object?>> get onMessageOpenedAppData {
    return _openedMessageController.stream;
  }

  void emitTokenRefresh(String token) {
    _tokenRefreshController.add(token);
  }

  Future<void> dispose() async {
    await _tokenRefreshController.close();
    await _openedMessageController.close();
  }
}
