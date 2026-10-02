import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:on_this_day_mobile/core/api/api_client.dart';
import 'package:on_this_day_mobile/core/config/timezone_provider.dart';
import 'package:on_this_day_mobile/core/notifications/device_platform_provider.dart';
import 'package:on_this_day_mobile/core/notifications/device_registration_client.dart';
import 'package:on_this_day_mobile/core/notifications/device_registration_coordinator.dart';
import 'package:on_this_day_mobile/core/notifications/notification_service.dart';
import 'package:on_this_day_mobile/core/notifications/registered_token_store.dart';

void main() {
  late _Harness harness;

  setUp(() => harness = _Harness());
  tearDown(() => harness.dispose());

  group('startup', () {
    test('authorized: registers, then persists the confirmed token', () async {
      await harness.start(NotificationPermissionStatus.authorized);

      expect(harness.log, ['POST current-token', 'store write current-token']);
      expect(harness.store.token, 'current-token');
      expect(harness.messaging.permissionRequestCount, 0);
      expect(
        harness.lastBody,
        contains('"notificationPermissionStatus":"authorized"'),
      );
      expect(harness.lastBody, contains('"platform":"ios"'));
      expect(harness.lastBody, contains('"timezone":"America/Jamaica"'));
    });

    test('a failed registration is not persisted', () async {
      harness.failPost = true;

      await harness.start(NotificationPermissionStatus.authorized);

      expect(harness.log, ['POST current-token (failed)']);
      expect(harness.store.token, isNull);
    });

    for (final status in [
      NotificationPermissionStatus.notDetermined,
      NotificationPermissionStatus.denied,
      NotificationPermissionStatus.permanentlyDenied,
    ]) {
      test(
        '$status without a registered token: no token, no requests',
        () async {
          await harness.start(status);

          expect(harness.messaging.tokenRequestCount, 0);
          expect(harness.messaging.permissionRequestCount, 0);
          expect(harness.log, isEmpty);
        },
      );

      test('$status with a registered token: deletes exactly it', () async {
        harness.store.token = 'old-registered';

        await harness.start(status);

        expect(harness.log, ['DELETE old-registered', 'store clear']);
        expect(harness.store.token, isNull);
        expect(harness.messaging.tokenRequestCount, 0);
      });
    }
  });

  group('revocation cleanup', () {
    test('retains the token after a failed DELETE and retries later', () async {
      harness.store.token = 'registered';
      harness.failDelete = true;

      await harness.start(NotificationPermissionStatus.denied);
      expect(harness.log, ['DELETE registered (failed)']);
      expect(harness.store.token, 'registered');

      harness.failDelete = false;
      await harness.coordinator.reconcile();

      expect(harness.log, [
        'DELETE registered (failed)',
        'DELETE registered',
        'store clear',
      ]);
      expect(harness.store.token, isNull);
    });

    test('a Settings change is picked up by reconcile()', () async {
      await harness.start(NotificationPermissionStatus.authorized);
      harness.messaging.status = NotificationPermissionStatus.denied;

      await harness.coordinator.reconcile();

      expect(harness.log, [
        'POST current-token',
        'store write current-token',
        'DELETE current-token',
        'store clear',
      ]);
      expect(harness.messaging.permissionRequestCount, 0);
    });

    test('re-allowing after a revocation registers again', () async {
      await harness.start(NotificationPermissionStatus.authorized);
      harness.messaging.status = NotificationPermissionStatus.denied;
      await harness.coordinator.reconcile();
      harness.messaging.status = NotificationPermissionStatus.authorized;

      await harness.coordinator.reconcile();

      expect(harness.log.last, 'store write current-token');
      expect(harness.store.token, 'current-token');
    });

    test('an unreadable permission status changes nothing', () async {
      harness.store.token = 'registered';
      harness.messaging.statusError = Exception('channel');

      await harness.coordinator.reconcile();

      expect(harness.log, isEmpty);
      expect(harness.store.token, 'registered');
    });
  });

  group('token refresh', () {
    test('registers the new token, deletes the old, then persists', () async {
      await harness.start(NotificationPermissionStatus.authorized);
      harness.log.clear();

      harness.messaging.emitTokenRefresh('new-token');
      await harness.settle();

      expect(harness.log, [
        'POST new-token',
        'DELETE current-token',
        'store write new-token',
      ]);
      expect(harness.store.token, 'new-token');
    });

    test('keeps the new token when deleting the old one fails', () async {
      await harness.start(NotificationPermissionStatus.authorized);
      harness.log.clear();
      harness.failDelete = true;

      harness.messaging.emitTokenRefresh('new-token');
      await harness.settle();

      expect(harness.log, [
        'POST new-token',
        'DELETE current-token (failed)',
        'store write new-token',
      ]);
    });

    test('does not send a refreshed token when not allowed', () async {
      await harness.start(NotificationPermissionStatus.authorized);
      harness.messaging.status = NotificationPermissionStatus.denied;
      harness.log.clear();

      harness.messaging.emitTokenRefresh('new-token');
      await harness.settle();

      expect(harness.log, ['DELETE current-token', 'store clear']);
      expect(harness.log.any((entry) => entry.contains('new-token')), isFalse);
    });
  });

  test('does not re-post an unchanged registration on resume', () async {
    await harness.start(NotificationPermissionStatus.authorized);

    await harness.coordinator.reconcile();
    await harness.coordinator.reconcile();

    expect(
      harness.log.where((entry) => entry.startsWith('POST')),
      hasLength(1),
    );
  });

  test('re-posts when the permission changes to provisional', () async {
    await harness.start(NotificationPermissionStatus.authorized);

    await harness.coordinator.registerAfterAuthorization(
      NotificationPermissionStatus.provisional,
    );

    expect(
      harness.log.where((entry) => entry.startsWith('POST')),
      hasLength(2),
    );
    expect(
      harness.lastBody,
      contains('"notificationPermissionStatus":"provisional"'),
    );
  });

  test('skips registration when no token is available yet', () async {
    harness.messaging.token = null;

    await harness.coordinator.registerAfterAuthorization(
      NotificationPermissionStatus.authorized,
    );

    expect(harness.messaging.tokenRequestCount, 1);
    expect(harness.log, isEmpty);
  });

  test('never logs a raw token', () async {
    final printed = <String>[];
    final original = debugPrint;
    debugPrint = (message, {wrapWidth}) => printed.add(message ?? '');
    addTearDown(() => debugPrint = original);
    harness.store.token = 'old-token';
    harness.failDelete = true;

    await harness.start(NotificationPermissionStatus.authorized);
    harness.messaging.status = NotificationPermissionStatus.denied;
    await harness.coordinator.reconcile();

    expect(printed, isNotEmpty);
    for (final line in printed) {
      expect(line, isNot(contains('old-token')), reason: line);
      expect(line, isNot(contains('current-token')), reason: line);
    }
  });
}

class _Harness {
  _Harness() {
    service = NotificationService(messaging: messaging);
    store = _LoggingTokenStore(log);
    coordinator = DeviceRegistrationCoordinator(
      client: DeviceRegistrationClient(
        apiClient: ApiClient(
          baseUrl: Uri.parse('http://127.0.0.1:3000'),
          httpClient: MockClient(_handle),
        ),
      ),
      timezoneProvider: const _FakeTimezoneProvider(),
      platformProvider: const PlatformDevicePlatformProvider(
        operatingSystem: 'ios',
      ),
      notificationService: service,
      registeredTokens: store,
    );
  }

  final List<String> log = [];
  final _FakeMessaging messaging = _FakeMessaging();
  late final NotificationService service;
  late final _LoggingTokenStore store;
  late final DeviceRegistrationCoordinator coordinator;
  bool failPost = false;
  bool failDelete = false;
  String? lastBody;

  Future<void> start(NotificationPermissionStatus status) async {
    messaging.status = status;
    await service.start();
    await coordinator.start(
      NotificationStartupState(permissionStatus: status, initialEventId: null),
    );
  }

  /// Lets queued refresh work finish, then waits for the serial queue.
  Future<void> settle() async {
    for (var i = 0; i < 10; i++) {
      await Future<void>.delayed(Duration.zero);
    }
    await coordinator.reconcile(status: messaging.status);
  }

  Future<http.Response> _handle(http.Request request) async {
    if (request.method == 'POST') {
      final token = RegExp(r'"token":"([^"]+)"').firstMatch(request.body)![1]!;
      lastBody = request.body;
      if (failPost) {
        log.add('POST $token (failed)');
        return http.Response('{"error":"unavailable"}', 503);
      }
      log.add('POST $token');
      return http.Response('{"registered":true}', 200);
    }
    final token = Uri.decodeComponent(request.url.pathSegments.last);
    if (failDelete) {
      log.add('DELETE $token (failed)');
      return http.Response('{"error":"unavailable"}', 503);
    }
    log.add('DELETE $token');
    return http.Response('{"deleted":true}', 200);
  }

  Future<void> dispose() async {
    await coordinator.dispose();
    await service.dispose();
    await messaging.dispose();
  }
}

class _LoggingTokenStore implements RegisteredTokenStore {
  _LoggingTokenStore(this.log);

  final List<String> log;
  String? token;

  @override
  Future<String?> read() async => token;

  @override
  Future<void> write(String value) async {
    log.add('store write $value');
    token = value;
  }

  @override
  Future<void> clear() async {
    log.add('store clear');
    token = null;
  }
}

class _FakeTimezoneProvider implements TimezoneProvider {
  const _FakeTimezoneProvider();

  @override
  Future<String> currentTimezone() async => 'America/Jamaica';
}

class _FakeMessaging implements NotificationMessaging {
  NotificationPermissionStatus status =
      NotificationPermissionStatus.notDetermined;
  String? token = 'current-token';
  Object? statusError;
  int permissionRequestCount = 0;
  int tokenRequestCount = 0;

  final StreamController<String> _refresh =
      StreamController<String>.broadcast();
  final StreamController<Map<String, Object?>> _opened =
      StreamController<Map<String, Object?>>.broadcast();
  final StreamController<ForegroundNotification> _foreground =
      StreamController<ForegroundNotification>.broadcast();

  @override
  Future<NotificationPermissionStatus> requestPermission() async {
    permissionRequestCount += 1;
    return status;
  }

  @override
  Future<NotificationPermissionStatus> getPermissionStatus() async {
    final error = statusError;
    if (error != null) throw error;
    return status;
  }

  @override
  Future<String?> getToken() async {
    tokenRequestCount += 1;
    return token;
  }

  @override
  Stream<String> get onTokenRefresh => _refresh.stream;

  @override
  Future<Map<String, Object?>?> getInitialMessageData() async => null;

  @override
  Stream<Map<String, Object?>> get onMessageOpenedAppData => _opened.stream;

  @override
  Stream<ForegroundNotification> get onForegroundMessage => _foreground.stream;

  void emitTokenRefresh(String value) {
    token = value;
    _refresh.add(value);
  }

  Future<void> dispose() async {
    await _refresh.close();
    await _opened.close();
    await _foreground.close();
  }
}
