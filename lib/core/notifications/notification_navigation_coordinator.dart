import 'dart:async';

import 'package:flutter/material.dart';

import '../navigation/app_routes.dart';
import 'notification_service.dart';

class NotificationNavigationCoordinator {
  NotificationNavigationCoordinator({
    required GlobalKey<NavigatorState> navigatorKey,
  }) : _navigatorKey = navigatorKey;

  final GlobalKey<NavigatorState> _navigatorKey;
  StreamSubscription<NotificationTap>? _subscription;

  Future<void> start(Stream<NotificationTap> notificationTaps) async {
    await _subscription?.cancel();
    _subscription = notificationTaps.listen((tap) {
      _navigatorKey.currentState?.pushNamed(AppRoutes.eventDetail(tap.eventId));
    });
  }

  Future<void> dispose() async {
    await _subscription?.cancel();
  }
}
