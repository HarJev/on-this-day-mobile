import 'dart:async';

import 'package:flutter/foundation.dart';

import '../config/timezone_provider.dart';
import 'device_platform_provider.dart';
import 'device_registration_client.dart';
import 'notification_service.dart';
import 'registered_token_store.dart';

/// Keeps the backend device registration in step with the system notification
/// permission. It never requests permission.
///
/// - Allowed (authorized/provisional): register the current token; persist it
///   only after the backend confirms registration.
/// - Not allowed (not determined/denied/permanently denied): delete only the
///   token previously confirmed as registered, and forget it only after the
///   backend confirms deletion. No new token is fetched or sent for this.
/// - Token refresh while allowed: register the new token, delete the old one
///   if different, then persist the new one.
///
/// Operations run one at a time so startup, token refresh, and resume
/// reconciliation cannot interleave. Failures are logged (never the token)
/// and left for the next reconciliation to retry.
class DeviceRegistrationCoordinator {
  DeviceRegistrationCoordinator({
    required DeviceRegistrationClient client,
    required TimezoneProvider timezoneProvider,
    required DevicePlatformProvider platformProvider,
    required NotificationService notificationService,
    required RegisteredTokenStore registeredTokens,
  }) : _client = client,
       _timezoneProvider = timezoneProvider,
       _platformProvider = platformProvider,
       _notificationService = notificationService,
       _registeredTokens = registeredTokens;

  final DeviceRegistrationClient _client;
  final TimezoneProvider _timezoneProvider;
  final DevicePlatformProvider _platformProvider;
  final NotificationService _notificationService;
  final RegisteredTokenStore _registeredTokens;

  StreamSubscription<String>? _tokenRefreshSubscription;
  NotificationPermissionStatus? _lastPermissionStatus;
  Future<void> _queue = Future<void>.value();

  /// What this session last confirmed with the backend, to avoid re-posting an
  /// unchanged registration on every resume.
  ({String token, NotificationPermissionStatus status})? _confirmed;

  /// Listens for token refreshes and reconciles the startup permission status.
  Future<void> start(NotificationStartupState startupState) async {
    await _tokenRefreshSubscription?.cancel();
    _tokenRefreshSubscription = _notificationService.tokenRefreshes.listen(
      (token) => unawaited(_enqueue(() => _handleRefresh(token))),
    );
    await reconcile(status: startupState.permissionStatus);
  }

  /// Aligns the backend registration with [status], or with the current
  /// system status when omitted (for example after returning from Settings).
  Future<void> reconcile({NotificationPermissionStatus? status}) =>
      _enqueue(() => _reconcile(status));

  /// Registers the device after the user has just allowed notifications.
  Future<void> registerAfterAuthorization(
    NotificationPermissionStatus status,
  ) => reconcile(status: status);

  Future<void> dispose() async {
    await _tokenRefreshSubscription?.cancel();
  }

  Future<void> _enqueue(Future<void> Function() operation) {
    final next = _queue.then<void>((_) => operation());
    _queue = next.then<void>((_) {}, onError: (Object _, StackTrace _) {});
    return next;
  }

  Future<void> _reconcile(NotificationPermissionStatus? requested) async {
    final status = requested ?? await _readPermissionStatus();
    if (status == null) {
      return;
    }
    _lastPermissionStatus = status;
    if (!status.allowsDelivery) {
      await _removeRegistration(reason: status.name);
      return;
    }
    final token = await _notificationService.currentToken();
    if (token == null || token.isEmpty) {
      _debugLog('registration_skipped reason=missing_token');
      return;
    }
    await _register(token, status);
  }

  Future<void> _handleRefresh(String token) async {
    final status =
        await _readPermissionStatus() ??
        _lastPermissionStatus ??
        NotificationPermissionStatus.notDetermined;
    _lastPermissionStatus = status;
    if (!status.allowsDelivery) {
      // Do not send the refreshed token; only remove what was registered.
      await _removeRegistration(reason: status.name);
      return;
    }
    if (token.isEmpty) {
      _debugLog('registration_skipped reason=empty_token');
      return;
    }
    await _register(token, status);
  }

  Future<void> _register(
    String token,
    NotificationPermissionStatus status,
  ) async {
    final confirmed = _confirmed;
    if (confirmed != null &&
        confirmed.token == token &&
        confirmed.status == status) {
      _debugLog('registration_skipped reason=already_confirmed');
      return;
    }

    final previous = await _readRegisteredToken();
    try {
      _debugLog('registration_start');
      final request = DeviceRegistrationRequest(
        token: token,
        platform: await _platformProvider.currentPlatform(),
        timezone: await _timezoneProvider.currentTimezone(),
        notificationPermissionStatus: status,
      );
      await _client.register(request);
      _debugLog(
        'registration_success platform=${request.platform.toJsonValue()} '
        'permissionStatus=${status.toJsonValue()}',
      );
    } catch (error) {
      _debugLog('registration_failure causeType=${error.runtimeType}');
      return;
    }
    _confirmed = (token: token, status: status);

    if (previous != null && previous != token) {
      try {
        await _client.deleteToken(previous);
        _debugLog('replaced_token_delete_success');
      } catch (error) {
        // The replaced token is already invalid at FCM; the backend prunes it
        // on its next permanent send failure.
        _debugLog(
          'replaced_token_delete_failure causeType=${error.runtimeType}',
        );
      }
    }

    try {
      await _registeredTokens.write(token);
    } catch (error) {
      _debugLog(
        'registered_token_persist_failure causeType=${error.runtimeType}',
      );
    }
  }

  Future<void> _removeRegistration({required String reason}) async {
    _confirmed = null;
    final token = await _readRegisteredToken();
    if (token == null) {
      _debugLog('cleanup_skipped reason=$reason no_registered_token');
      return;
    }
    try {
      await _client.deleteToken(token);
      _debugLog('cleanup_delete_success reason=$reason');
    } catch (error) {
      // Keep the token so the next reconciliation retries the deletion.
      _debugLog('cleanup_delete_failure causeType=${error.runtimeType}');
      return;
    }
    try {
      await _registeredTokens.clear();
    } catch (error) {
      _debugLog(
        'registered_token_clear_failure causeType=${error.runtimeType}',
      );
    }
  }

  Future<String?> _readRegisteredToken() async {
    try {
      return await _registeredTokens.read();
    } catch (error) {
      _debugLog('registered_token_read_failure causeType=${error.runtimeType}');
      return null;
    }
  }

  Future<NotificationPermissionStatus?> _readPermissionStatus() async {
    try {
      return await _notificationService.currentPermissionStatus();
    } catch (error) {
      _debugLog('permission_status_failure causeType=${error.runtimeType}');
      return null;
    }
  }

  void _debugLog(String message) {
    if (kDebugMode) {
      debugPrint('[DeviceRegistrationCoordinator] $message');
    }
  }
}
