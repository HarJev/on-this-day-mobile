import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:on_this_day_mobile/core/notifications/local_notification_gateway.dart';
import 'package:on_this_day_mobile/core/notifications/notification_service.dart';

void main() {
  group('NotificationService', () {
    test('requests permission and returns current token', () async {
      final messaging = _FakeNotificationMessaging(
        token: 'fcm-token',
        permissionStatus: NotificationPermissionStatus.authorized,
      );
      final service = NotificationService(messaging: messaging);

      final state = await service.start();

      expect(messaging.permissionRequestCount, 1);
      expect(messaging.tokenRequestCount, 1);
      expect(state.permissionStatus, NotificationPermissionStatus.authorized);
      expect(state.currentToken, 'fcm-token');

      await service.dispose();
      await messaging.dispose();
    });

    test('keeps bootstrapping when current token lookup fails', () async {
      final messaging = _FakeNotificationMessaging(
        tokenException: Exception('APNs token not ready'),
      );
      final service = NotificationService(messaging: messaging);

      final state = await service.start();

      expect(state.currentToken, isNull);
      expect(state.permissionStatus, NotificationPermissionStatus.authorized);

      await service.dispose();
      await messaging.dispose();
    });

    test('listens for token refresh', () async {
      final messaging = _FakeNotificationMessaging();
      final service = NotificationService(messaging: messaging);

      await service.start();

      final expectation = expectLater(
        service.tokenRefreshes,
        emits('refreshed-token'),
      );
      messaging.emitTokenRefresh('refreshed-token');
      await expectation;

      await service.dispose();
      await messaging.dispose();
    });

    test('returns initial notification event ID', () async {
      final messaging = _FakeNotificationMessaging(
        initialMessageData: const {'eventId': 'battle-of-bosworth-field-1485'},
      );
      final service = NotificationService(messaging: messaging);

      final state = await service.start();

      expect(state.initialEventId, 'battle-of-bosworth-field-1485');

      await service.dispose();
      await messaging.dispose();
    });

    test('emits notification taps from opened app messages', () async {
      final messaging = _FakeNotificationMessaging();
      final service = NotificationService(messaging: messaging);

      await service.start();

      final expectation = expectLater(
        service.notificationTaps,
        emits(
          isA<NotificationTap>().having(
            (tap) => tap.eventId,
            'eventId',
            'vesuvius-erupts-79',
          ),
        ),
      );
      messaging.emitOpenedMessage(const {'eventId': 'vesuvius-erupts-79'});
      await expectation;

      await service.dispose();
      await messaging.dispose();
    });

    test('returns initial event ID from a local notification launch', () async {
      final messaging = _FakeNotificationMessaging();
      final localNotifications = _FakeLocalNotificationGateway(
        initialPayload: '{"eventId":"battle-of-bosworth-field-1485"}',
      );
      final service = NotificationService(
        messaging: messaging,
        localNotifications: localNotifications,
      );

      final state = await service.start();

      expect(state.initialEventId, 'battle-of-bosworth-field-1485');

      await service.dispose();
      await messaging.dispose();
    });

    test('emits local and Firebase taps through the same stream', () async {
      final messaging = _FakeNotificationMessaging();
      final localNotifications = _FakeLocalNotificationGateway();
      final service = NotificationService(
        messaging: messaging,
        localNotifications: localNotifications,
      );
      await service.start();

      final eventIds = <String>[];
      final subscription = service.notificationTaps.listen(
        (tap) => eventIds.add(tap.eventId),
      );
      localNotifications.emitTap('{"eventId":"local-event"}');
      messaging.emitOpenedMessage(const {'eventId': 'firebase-event'});
      await Future<void>.delayed(Duration.zero);

      expect(eventIds, ['local-event', 'firebase-event']);

      await subscription.cancel();
      await service.dispose();
      await messaging.dispose();
    });

    test('shows a debug local notification with the shared payload', () async {
      final messaging = _FakeNotificationMessaging();
      final localNotifications = _FakeLocalNotificationGateway();
      final service = NotificationService(
        messaging: messaging,
        localNotifications: localNotifications,
      );
      await service.start();

      await service.showDebugTestNotification(eventId: 'test-event');

      expect(localNotifications.lastTitle, 'A moment in history is waiting');
      expect(localNotifications.lastPayload, '{"eventId":"test-event"}');

      await service.dispose();
      await messaging.dispose();
    });
  });
}

class _FakeLocalNotificationGateway implements LocalNotificationGateway {
  _FakeLocalNotificationGateway({this.initialPayload});

  final String? initialPayload;
  final StreamController<String> _tapController =
      StreamController<String>.broadcast();

  String? lastTitle;
  String? lastPayload;

  @override
  Stream<String> get notificationTaps => _tapController.stream;

  @override
  Future<String?> start() async => initialPayload;

  @override
  Future<void> show({
    required String title,
    required String body,
    required String payload,
  }) async {
    lastTitle = title;
    lastPayload = payload;
  }

  void emitTap(String payload) {
    _tapController.add(payload);
  }

  @override
  Future<void> dispose() async {
    await _tapController.close();
  }
}

class _FakeNotificationMessaging implements NotificationMessaging {
  _FakeNotificationMessaging({
    this.token = 'token',
    this.tokenException,
    this.permissionStatus = NotificationPermissionStatus.authorized,
    this.initialMessageData,
  });

  final String? token;
  final Object? tokenException;
  final NotificationPermissionStatus permissionStatus;
  final Map<String, Object?>? initialMessageData;

  final StreamController<String> _tokenRefreshController =
      StreamController<String>.broadcast();
  final StreamController<Map<String, Object?>> _openedMessageController =
      StreamController<Map<String, Object?>>.broadcast();

  int permissionRequestCount = 0;
  int tokenRequestCount = 0;

  @override
  Future<NotificationPermissionStatus> requestPermission() async {
    permissionRequestCount += 1;
    return permissionStatus;
  }

  @override
  Future<NotificationPermissionStatus> getPermissionStatus() async {
    return permissionStatus;
  }

  @override
  Future<String?> getToken() async {
    tokenRequestCount += 1;
    final exception = tokenException;
    if (exception != null) {
      throw exception;
    }

    return token;
  }

  @override
  Stream<String> get onTokenRefresh => _tokenRefreshController.stream;

  @override
  Future<Map<String, Object?>?> getInitialMessageData() async {
    return initialMessageData;
  }

  @override
  Stream<Map<String, Object?>> get onMessageOpenedAppData {
    return _openedMessageController.stream;
  }

  void emitTokenRefresh(String token) {
    _tokenRefreshController.add(token);
  }

  void emitOpenedMessage(Map<String, Object?> data) {
    _openedMessageController.add(data);
  }

  Future<void> dispose() async {
    await _tokenRefreshController.close();
    await _openedMessageController.close();
  }
}
