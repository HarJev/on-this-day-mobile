import 'dart:async';

import 'package:flutter/foundation.dart';

import 'notification_prompt_store.dart';
import 'notification_service.dart';

/// What happened after the user chose "Turn on notifications".
enum NotificationPromptOutcome {
  /// Notifications are allowed (authorized or provisional).
  enabled,

  /// The system reports notifications as off; only device Settings can change it.
  blocked,

  /// The system prompt closed without a decision.
  undecided,

  /// The request could not be completed; nothing was recorded.
  failed,
}

/// Decides when to offer the in-app notification pre-prompt and performs the
/// system permission request only when the user explicitly asks for it.
class NotificationPromptCoordinator {
  NotificationPromptCoordinator({
    required NotificationPermissionGateway permissions,
    required NotificationPromptStore store,
    required Future<void> Function(NotificationPermissionStatus status)
    onAuthorized,
    required bool deniedMayBeUnasked,
  }) : _permissions = permissions,
       _store = store,
       _onAuthorized = onAuthorized,
       _deniedMayBeUnasked = deniedMayBeUnasked;

  final NotificationPermissionGateway _permissions;
  final NotificationPromptStore _store;
  final Future<void> Function(NotificationPermissionStatus status)
  _onAuthorized;

  /// Android 13+ reports notifications as denied before the app has ever asked,
  /// so an unrecorded denial may still be askable there. On iOS a denial means
  /// the system prompt will not appear again.
  final bool _deniedMayBeUnasked;

  /// Whether the pre-prompt should be shown now. Never shows the system prompt.
  Future<bool> shouldOffer() async {
    final NotificationPromptDecision? decision;
    try {
      decision = await _store.read();
    } catch (error) {
      // Unreadable preferences must not turn into repeated prompting.
      _debugLog('should_offer_store_failure cause=$error');
      return false;
    }
    if (decision != null) {
      return false;
    }

    final NotificationPermissionStatus status;
    try {
      status = await _permissions.currentPermissionStatus();
    } catch (error) {
      _debugLog('should_offer_status_failure cause=$error');
      return false;
    }

    return switch (status) {
      NotificationPermissionStatus.notDetermined => true,
      NotificationPermissionStatus.denied => _deniedMayBeUnasked,
      NotificationPermissionStatus.authorized ||
      NotificationPermissionStatus.provisional ||
      NotificationPermissionStatus.permanentlyDenied => false,
    };
  }

  /// Requests system permission. Registration continues in the background so
  /// the caller is never blocked on network or token retrieval.
  Future<NotificationPromptOutcome> enable() async {
    final NotificationPermissionStatus status;
    try {
      status = await _permissions.requestPermission();
    } catch (error) {
      _debugLog('enable_request_failure cause=$error');
      return NotificationPromptOutcome.failed;
    }

    await _record(NotificationPromptDecision.requested);

    if (status.allowsDelivery) {
      unawaited(_registerSafely(status));
      return NotificationPromptOutcome.enabled;
    }
    return switch (status) {
      NotificationPermissionStatus.notDetermined =>
        NotificationPromptOutcome.undecided,
      _ => NotificationPromptOutcome.blocked,
    };
  }

  /// Records "Not now" so the pre-prompt is not offered again.
  Future<void> decline() => _record(NotificationPromptDecision.declined);

  Future<void> _record(NotificationPromptDecision decision) async {
    try {
      await _store.write(decision);
    } catch (error) {
      _debugLog('record_failure decision=${decision.name} cause=$error');
    }
  }

  Future<void> _registerSafely(NotificationPermissionStatus status) async {
    try {
      await _onAuthorized(status);
    } catch (error) {
      _debugLog('registration_after_enable_failure cause=$error');
    }
  }

  void _debugLog(String message) {
    if (kDebugMode) {
      debugPrint('[NotificationPromptCoordinator] $message');
    }
  }
}
