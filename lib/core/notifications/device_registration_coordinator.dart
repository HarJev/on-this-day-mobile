import 'dart:async';

import 'package:flutter/foundation.dart';

import '../config/timezone_provider.dart';
import 'device_platform_provider.dart';
import 'device_registration_client.dart';
import 'notification_service.dart';

class DeviceRegistrationCoordinator {
  DeviceRegistrationCoordinator({
    required DeviceRegistrationClient client,
    required TimezoneProvider timezoneProvider,
    required DevicePlatformProvider platformProvider,
    required NotificationService notificationService,
  }) : _client = client,
       _timezoneProvider = timezoneProvider,
       _platformProvider = platformProvider,
       _notificationService = notificationService;

  final DeviceRegistrationClient _client;
  final TimezoneProvider _timezoneProvider;
  final DevicePlatformProvider _platformProvider;
  final NotificationService _notificationService;

  StreamSubscription<String>? _tokenRefreshSubscription;
  NotificationPermissionStatus? _lastPermissionStatus;

  Future<void> start(NotificationStartupState startupState) async {
    _lastPermissionStatus = startupState.permissionStatus;
    await _tokenRefreshSubscription?.cancel();
    _tokenRefreshSubscription = _notificationService.tokenRefreshes.listen((
      token,
    ) {
      unawaited(_registerToken(token, refreshPermissionStatus: true));
    });

    final token = startupState.currentToken;
    if (token == null || token.isEmpty) {
      _debugLog('startup_registration_skipped reason=missing_token');
      return;
    }

    await _registerToken(token, refreshPermissionStatus: false);
  }

  Future<void> deleteToken(String token) async {
    try {
      _debugLog('delete_start');
      await _client.deleteToken(token);
      _debugLog('delete_success');
    } catch (error) {
      _debugLog('delete_failure causeType=${error.runtimeType} cause=$error');
    }
  }

  Future<void> dispose() async {
    await _tokenRefreshSubscription?.cancel();
  }

  Future<void> _registerToken(
    String token, {
    required bool refreshPermissionStatus,
  }) async {
    if (token.isEmpty) {
      _debugLog('registration_skipped reason=empty_token');
      return;
    }

    try {
      _debugLog('registration_start');
      final permissionStatus = await _permissionStatus(
        refresh: refreshPermissionStatus,
      );
      final request = DeviceRegistrationRequest(
        token: token,
        platform: await _platformProvider.currentPlatform(),
        timezone: await _timezoneProvider.currentTimezone(),
        notificationPermissionStatus: permissionStatus,
      );
      await _client.register(request);
      _debugLog(
        'registration_success platform=${request.platform.toJsonValue()} '
        'permissionStatus=${permissionStatus.toJsonValue()}',
      );
    } catch (error) {
      _debugLog(
        'registration_failure causeType=${error.runtimeType} cause=$error',
      );
    }
  }

  Future<NotificationPermissionStatus> _permissionStatus({
    required bool refresh,
  }) async {
    if (refresh) {
      try {
        final status = await _notificationService.currentPermissionStatus();
        _lastPermissionStatus = status;
        return status;
      } catch (error) {
        _debugLog(
          'permission_status_refresh_failure '
          'causeType=${error.runtimeType} cause=$error',
        );
      }
    }

    return _lastPermissionStatus ?? NotificationPermissionStatus.notDetermined;
  }

  void _debugLog(String message) {
    if (kDebugMode) {
      debugPrint('[DeviceRegistrationCoordinator] $message');
    }
  }
}
