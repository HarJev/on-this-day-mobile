import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';

abstract interface class LocalNotificationGateway {
  Stream<String> get notificationTaps;

  Future<String?> start();

  Future<void> show({
    required String title,
    required String body,
    required String payload,
  });

  Future<void> dispose();
}

class PlatformLocalNotificationGateway implements LocalNotificationGateway {
  PlatformLocalNotificationGateway({FlutterLocalNotificationsPlugin? plugin})
    : _plugin = plugin ?? FlutterLocalNotificationsPlugin();

  static const _notificationId = 1001;
  static const _channelId = 'on_this_day_debug';
  static const _channelName = 'On This Day debug notifications';

  final FlutterLocalNotificationsPlugin _plugin;
  final StreamController<String> _tapController =
      StreamController<String>.broadcast();

  bool get _isSupportedMobilePlatform {
    return !kIsWeb &&
        (defaultTargetPlatform == TargetPlatform.android ||
            defaultTargetPlatform == TargetPlatform.iOS);
  }

  @override
  Stream<String> get notificationTaps => _tapController.stream;

  @override
  Future<String?> start() async {
    if (!_isSupportedMobilePlatform) {
      return null;
    }

    await _plugin.initialize(
      settings: const InitializationSettings(
        android: AndroidInitializationSettings('@mipmap/ic_launcher'),
        iOS: DarwinInitializationSettings(
          requestAlertPermission: false,
          requestBadgePermission: false,
          requestSoundPermission: false,
        ),
      ),
      onDidReceiveNotificationResponse: (response) {
        final payload = response.payload;
        if (payload != null && payload.isNotEmpty) {
          _tapController.add(payload);
        }
      },
    );

    final launchDetails = await _plugin.getNotificationAppLaunchDetails();
    if (launchDetails?.didNotificationLaunchApp != true) {
      return null;
    }
    return launchDetails?.notificationResponse?.payload;
  }

  @override
  Future<void> show({
    required String title,
    required String body,
    required String payload,
  }) async {
    if (!_isSupportedMobilePlatform) {
      return;
    }

    await _plugin.show(
      id: _notificationId,
      title: title,
      body: body,
      payload: payload,
      notificationDetails: const NotificationDetails(
        android: AndroidNotificationDetails(
          _channelId,
          _channelName,
          channelDescription: 'Local notification deep-link testing.',
          importance: Importance.high,
          priority: Priority.high,
        ),
        iOS: DarwinNotificationDetails(
          presentAlert: true,
          presentBanner: true,
          presentList: true,
          presentSound: true,
        ),
      ),
    );
  }

  @override
  Future<void> dispose() async {
    await _tapController.close();
  }
}
