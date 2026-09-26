import 'dart:async';

import 'package:flutter/widgets.dart';

/// Re-checks notification permission whenever the app returns to the
/// foreground, for example after the user changes it in device Settings.
/// It only reads state; it never requests permission.
class NotificationResumeReconciler {
  NotificationResumeReconciler({required Future<void> Function() reconcile})
    : _reconcile = reconcile;

  final Future<void> Function() _reconcile;
  AppLifecycleListener? _listener;

  void start() {
    _listener ??= AppLifecycleListener(onResume: _onResume);
  }

  void dispose() {
    _listener?.dispose();
    _listener = null;
  }

  void _onResume() {
    unawaited(
      _reconcile().catchError((Object _) {
        // Reconciliation is best effort; the next resume retries.
      }),
    );
  }
}
