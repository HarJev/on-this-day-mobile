import 'dart:async';
import 'package:firebase_analytics/firebase_analytics.dart';
import 'package:firebase_crashlytics/firebase_crashlytics.dart';
import 'package:flutter/foundation.dart';

enum TelemetryScreen {
  today,
  quizHub,
  eventDetail,
  dailySetup,
  quickPlaySetup,
  gameplay,
  results,
  review,
}

abstract interface class AppTelemetry {
  void screenViewed(TelemetryScreen screen);
  void todayLoaded();
  void recentOpened();
  void quizStarted({required bool daily, required int questionCount});
  void quizCompleted({required bool daily, required int questionCount});
  void imagePreparationFailed(String category);
  void notificationPromptDecision(String outcome);
}

final class NoopAppTelemetry implements AppTelemetry {
  const NoopAppTelemetry();

  @override
  void screenViewed(TelemetryScreen screen) {}

  @override
  void todayLoaded() {}

  @override
  void recentOpened() {}

  @override
  void quizStarted({required bool daily, required int questionCount}) {}

  @override
  void quizCompleted({required bool daily, required int questionCount}) {}

  @override
  void imagePreparationFailed(String category) {}

  @override
  void notificationPromptDecision(String outcome) {}
}

/// Only a reviewed release build can enable collection. Native configuration
/// separately defaults both SDKs to off before Dart starts.
final class FirebaseAppTelemetry implements AppTelemetry {
  FirebaseAppTelemetry({
    required FirebaseAnalytics analytics,
    required FirebaseCrashlytics crashlytics,
  }) : _analytics = analytics,
       _crashlytics = crashlytics;

  static const releaseCollectionApproved = bool.fromEnvironment(
    'ON_THIS_DAY_TELEMETRY_ENABLED',
    defaultValue: false,
  );

  final FirebaseAnalytics _analytics;
  final FirebaseCrashlytics _crashlytics;
  bool _enabled = false;

  Future<void> configure() async {
    final enabled = kReleaseMode && releaseCollectionApproved;
    try {
      await _analytics.setAnalyticsCollectionEnabled(enabled);
      await _crashlytics.setCrashlyticsCollectionEnabled(enabled);
    } catch (error) {
      // Telemetry must never prevent a reader from opening the app.
      _enabled = false;
      try {
        await _analytics.setAnalyticsCollectionEnabled(false);
        await _crashlytics.setCrashlyticsCollectionEnabled(false);
      } catch (_) {}
      if (kDebugMode) {
        debugPrint('telemetry_configuration_failed type=${error.runtimeType}');
      }
      return;
    }
    _enabled = enabled;
    if (!enabled) return;

    final previousFlutterHandler = FlutterError.onError;
    FlutterError.onError = (details) {
      previousFlutterHandler?.call(details);
      _send(() => _crashlytics.recordFlutterFatalError(details));
    };
    final previousPlatformHandler = PlatformDispatcher.instance.onError;
    PlatformDispatcher.instance.onError = (error, stack) {
      _send(() => _crashlytics.recordError(error, stack, fatal: true));
      return previousPlatformHandler?.call(error, stack) ?? true;
    };
  }

  @override
  void screenViewed(TelemetryScreen screen) => _send(
    () => _analytics.logEvent(
      name: 'history_screen_viewed',
      parameters: {'screen': screen.name},
    ),
  );

  @override
  void todayLoaded() =>
      _send(() => _analytics.logEvent(name: 'history_today_loaded'));

  @override
  void recentOpened() =>
      _send(() => _analytics.logEvent(name: 'history_recent_opened'));

  @override
  void quizStarted({required bool daily, required int questionCount}) =>
      _quizEvent('quiz_started', daily, questionCount);

  @override
  void quizCompleted({required bool daily, required int questionCount}) =>
      _quizEvent('quiz_completed', daily, questionCount);

  @override
  void imagePreparationFailed(String category) {
    const allowed = {
      'timeout',
      'http',
      'encodedLimit',
      'decodedLimit',
      'decoding',
      'missing',
    };
    _send(
      () => _analytics.logEvent(
        name: 'quiz_image_preparation_failed',
        parameters: {
          'category': allowed.contains(category) ? category : 'other',
        },
      ),
    );
  }

  @override
  void notificationPromptDecision(String outcome) {
    const allowed = {'enabled', 'blocked', 'undecided', 'failed', 'not_now'};
    _send(
      () => _analytics.logEvent(
        name: 'history_notification_prompt',
        parameters: {'outcome': allowed.contains(outcome) ? outcome : 'other'},
      ),
    );
  }

  void _quizEvent(String name, bool daily, int questionCount) => _send(
    () => _analytics.logEvent(
      name: name,
      parameters: {
        'mode': daily ? 'daily' : 'quick_play',
        'question_count': questionCount,
      },
    ),
  );

  void _send(Future<void> Function() action) {
    if (!_enabled) return;
    unawaited(Future<void>.sync(action).catchError((Object _) {}));
  }
}
