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
///
/// "Not now" policy: the first decline pauses the offer for [reofferAfter];
/// after that it may appear once more on a later eligible Event Detail visit.
/// A second decline, or any completed system request, ends the offers.
class NotificationPromptCoordinator {
  NotificationPromptCoordinator({
    required NotificationPermissionGateway permissions,
    required NotificationPromptStore store,
    required Future<void> Function(NotificationPermissionStatus status)
    onAuthorized,
    required bool deniedMayBeUnasked,
    DateTime Function()? now,
    void Function(String outcome)? onDecision,
  }) : _permissions = permissions,
       _store = store,
       _onAuthorized = onAuthorized,
       _deniedMayBeUnasked = deniedMayBeUnasked,
       _now = now ?? DateTime.now,
       _onDecision = onDecision;

  /// How long the first "Not now" pauses the offer.
  static const reofferAfter = Duration(days: 30);

  /// Declines after which the offer never returns.
  static const maxDeclines = 2;

  final NotificationPermissionGateway _permissions;
  final NotificationPromptStore _store;
  final Future<void> Function(NotificationPermissionStatus status)
  _onAuthorized;
  final DateTime Function() _now;
  final void Function(String outcome)? _onDecision;

  /// Android 13+ reports notifications as denied before the app has ever asked,
  /// so an unrecorded denial may still be askable there. On iOS a denial means
  /// the system prompt will not appear again.
  final bool _deniedMayBeUnasked;

  /// Whether the pre-prompt should be shown now. Never shows the system prompt.
  Future<bool> shouldOffer() async {
    final NotificationPromptRecord? record;
    try {
      record = await _store.read();
    } catch (error) {
      // Unreadable or unrecognized preferences must not turn into repeated
      // prompting.
      _debugLog('should_offer_store_failure causeType=${error.runtimeType}');
      return false;
    }
    if (record != null && !_recordAllowsOffer(record)) {
      return false;
    }

    final NotificationPermissionStatus status;
    try {
      status = await _permissions.currentPermissionStatus();
    } catch (error) {
      _debugLog('should_offer_status_failure causeType=${error.runtimeType}');
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
      _debugLog('enable_request_failure causeType=${error.runtimeType}');
      _onDecision?.call(NotificationPromptOutcome.failed.name);
      return NotificationPromptOutcome.failed;
    }

    await _update((record) => record.withRequest);

    if (status.allowsDelivery) {
      unawaited(_registerSafely(status));
      _onDecision?.call(NotificationPromptOutcome.enabled.name);
      return NotificationPromptOutcome.enabled;
    }
    final outcome = switch (status) {
      NotificationPermissionStatus.notDetermined =>
        NotificationPromptOutcome.undecided,
      _ => NotificationPromptOutcome.blocked,
    };
    _onDecision?.call(outcome.name);
    return outcome;
  }

  /// Records "Not now". Never requests permission.
  Future<void> decline() async {
    await _update((record) => record.declinedOn(_now()));
    _onDecision?.call('not_now');
  }

  bool _recordAllowsOffer(NotificationPromptRecord record) {
    if (record.requested || record.declineCount >= maxDeclines) {
      return false;
    }
    if (record.declineCount == 0) {
      return true;
    }
    final declinedAt = record.declinedAt;
    if (declinedAt == null) {
      return false;
    }
    return !_now().toUtc().isBefore(declinedAt.add(reofferAfter));
  }

  Future<void> _update(
    NotificationPromptRecord Function(NotificationPromptRecord record) change,
  ) async {
    final NotificationPromptRecord? current;
    try {
      current = await _store.read();
    } catch (error) {
      // Leave unreadable data in place: it already suppresses the offer.
      _debugLog('record_read_failure causeType=${error.runtimeType}');
      return;
    }
    try {
      await _store.write(change(current ?? const NotificationPromptRecord()));
    } catch (error) {
      _debugLog('record_write_failure causeType=${error.runtimeType}');
    }
  }

  Future<void> _registerSafely(NotificationPermissionStatus status) async {
    try {
      await _onAuthorized(status);
    } catch (error) {
      _debugLog(
        'registration_after_enable_failure causeType=${error.runtimeType}',
      );
    }
  }

  void _debugLog(String message) {
    if (kDebugMode) {
      debugPrint('[NotificationPromptCoordinator] $message');
    }
  }
}
