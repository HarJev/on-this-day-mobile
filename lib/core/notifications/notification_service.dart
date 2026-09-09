import 'dart:async';

import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';

import 'local_notification_gateway.dart';
import 'notification_payload_parser.dart';

enum NotificationPermissionStatus {
  authorized,
  denied,
  notDetermined,
  provisional,
}

class NotificationStartupState {
  const NotificationStartupState({
    required this.permissionStatus,
    required this.currentToken,
    required this.initialEventId,
  });

  final NotificationPermissionStatus permissionStatus;
  final String? currentToken;
  final String? initialEventId;
}

class NotificationTap {
  const NotificationTap({required this.eventId}) : assert(eventId != '');

  final String eventId;
}

abstract interface class NotificationMessaging {
  Future<NotificationPermissionStatus> requestPermission();

  Future<NotificationPermissionStatus> getPermissionStatus();

  Future<String?> getToken();

  Stream<String> get onTokenRefresh;

  Future<Map<String, Object?>?> getInitialMessageData();

  Stream<Map<String, Object?>> get onMessageOpenedAppData;
}

class FirebaseNotificationMessaging implements NotificationMessaging {
  FirebaseNotificationMessaging({FirebaseMessaging? messaging})
    : _messaging = messaging ?? FirebaseMessaging.instance;

  final FirebaseMessaging _messaging;

  @override
  Future<NotificationPermissionStatus> requestPermission() async {
    final settings = await _messaging.requestPermission(
      alert: true,
      badge: true,
      sound: true,
    );

    return switch (settings.authorizationStatus) {
      final status => status.toNotificationPermissionStatus(),
    };
  }

  @override
  Future<NotificationPermissionStatus> getPermissionStatus() async {
    final settings = await _messaging.getNotificationSettings();
    return settings.authorizationStatus.toNotificationPermissionStatus();
  }

  @override
  Future<String?> getToken() {
    return _messaging.getToken();
  }

  @override
  Stream<String> get onTokenRefresh => _messaging.onTokenRefresh;

  @override
  Future<Map<String, Object?>?> getInitialMessageData() async {
    final message = await _messaging.getInitialMessage();
    return message == null ? null : Map<String, Object?>.from(message.data);
  }

  @override
  Stream<Map<String, Object?>> get onMessageOpenedAppData {
    return FirebaseMessaging.onMessageOpenedApp.map(
      (message) => Map<String, Object?>.from(message.data),
    );
  }
}

class NotificationService {
  NotificationService({
    required NotificationMessaging messaging,
    LocalNotificationGateway? localNotifications,
    NotificationPayloadParser payloadParser = const NotificationPayloadParser(),
  }) : _messaging = messaging,
       _localNotifications = localNotifications,
       _payloadParser = payloadParser;

  final NotificationMessaging _messaging;
  final LocalNotificationGateway? _localNotifications;
  final NotificationPayloadParser _payloadParser;
  final StreamController<String> _tokenRefreshController =
      StreamController<String>.broadcast();
  final StreamController<NotificationTap> _tapController =
      StreamController<NotificationTap>.broadcast();

  StreamSubscription<String>? _tokenRefreshSubscription;
  StreamSubscription<Map<String, Object?>>? _messageOpenedSubscription;
  StreamSubscription<String>? _localNotificationTapSubscription;

  Stream<String> get tokenRefreshes => _tokenRefreshController.stream;

  Stream<NotificationTap> get notificationTaps => _tapController.stream;

  Future<NotificationPermissionStatus> currentPermissionStatus() {
    return _messaging.getPermissionStatus();
  }

  Future<NotificationStartupState> start() async {
    final localInitialPayload = await _startLocalNotifications();

    _debugLog('permission_request_start');
    final permissionStatus = await _messaging.requestPermission();
    _debugLog('permission_request_end status=$permissionStatus');

    final currentToken = await _getCurrentToken();
    await _listenForTokenRefresh();

    final initialMessageData = await _messaging.getInitialMessageData();
    final initialEventId =
        _payloadParser.eventIdFromJson(localInitialPayload) ??
        _payloadParser.eventIdFromData(initialMessageData);
    _listenForNotificationTaps();

    return NotificationStartupState(
      permissionStatus: permissionStatus,
      currentToken: currentToken,
      initialEventId: initialEventId,
    );
  }

  Future<void> dispose() async {
    await _tokenRefreshSubscription?.cancel();
    await _messageOpenedSubscription?.cancel();
    await _localNotificationTapSubscription?.cancel();
    await _localNotifications?.dispose();
    await _tokenRefreshController.close();
    await _tapController.close();
  }

  Future<void> showDebugTestNotification({required String eventId}) async {
    if (!kDebugMode) {
      return;
    }

    final localNotifications = _localNotifications;
    if (localNotifications == null) {
      _debugLog('local_test_notification_skipped reason=not_configured');
      return;
    }

    _debugLog('local_test_notification_show eventId=$eventId');
    await localNotifications.show(
      title: 'A moment in history is waiting',
      body: 'Tap to open the linked event.',
      payload: _payloadParser.toJson(eventId),
    );
  }

  Future<String?> _startLocalNotifications() async {
    final localNotifications = _localNotifications;
    if (localNotifications == null) {
      return null;
    }

    try {
      final initialPayload = await localNotifications.start();
      await _localNotificationTapSubscription?.cancel();
      _localNotificationTapSubscription = localNotifications.notificationTaps
          .listen(_handleLocalNotificationTap);
      return initialPayload;
    } catch (error) {
      _debugLog(
        'local_notification_start_failure '
        'causeType=${error.runtimeType} cause=$error',
      );
      return null;
    }
  }

  Future<String?> _getCurrentToken() async {
    try {
      _debugLog('token_get_start');
      final token = await _messaging.getToken();
      _debugLog('token_get_end hasToken=${token != null}');
      return token;
    } catch (error) {
      _debugLog(
        'token_get_failure causeType=${error.runtimeType} cause=$error',
      );
      return null;
    }
  }

  Future<void> _listenForTokenRefresh() async {
    await _tokenRefreshSubscription?.cancel();
    _tokenRefreshSubscription = _messaging.onTokenRefresh.listen((token) {
      _debugLog('token_refresh hasToken=${token.isNotEmpty}');
      _tokenRefreshController.add(token);
    });
  }

  void _listenForNotificationTaps() {
    _messageOpenedSubscription?.cancel();
    _messageOpenedSubscription = _messaging.onMessageOpenedAppData.listen((
      data,
    ) {
      final eventId = _payloadParser.eventIdFromData(data);
      if (eventId == null) {
        _debugLog('notification_tap_missing_event_id');
        return;
      }

      _debugLog('notification_tap eventId=$eventId');
      _tapController.add(NotificationTap(eventId: eventId));
    });
  }

  void _handleLocalNotificationTap(String payload) {
    final eventId = _payloadParser.eventIdFromJson(payload);
    if (eventId == null) {
      _debugLog('local_notification_tap_invalid_payload');
      return;
    }

    _debugLog('local_notification_tap eventId=$eventId');
    _tapController.add(NotificationTap(eventId: eventId));
  }

  void _debugLog(String message) {
    if (kDebugMode) {
      debugPrint('[NotificationService] $message');
    }
  }
}

extension on AuthorizationStatus {
  NotificationPermissionStatus toNotificationPermissionStatus() {
    return switch (this) {
      AuthorizationStatus.authorized => NotificationPermissionStatus.authorized,
      AuthorizationStatus.denied => NotificationPermissionStatus.denied,
      AuthorizationStatus.deniedPermanently =>
        NotificationPermissionStatus.denied,
      AuthorizationStatus.notDetermined =>
        NotificationPermissionStatus.notDetermined,
      AuthorizationStatus.provisional =>
        NotificationPermissionStatus.provisional,
    };
  }
}
