import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:on_this_day_mobile/core/navigation/root_tab_controller.dart';
import 'package:on_this_day_mobile/core/telemetry/app_telemetry.dart';
import 'package:on_this_day_mobile/core/telemetry/telemetry_route_observer.dart';

void main() {
  testWidgets('reports only fixed screen names across tabs and routes', (
    tester,
  ) async {
    final telemetry = _RecordingTelemetry();
    final tabs = RootTabController();
    final navigatorKey = GlobalKey<NavigatorState>();
    final observer = TelemetryRouteObserver(
      telemetry: telemetry,
      rootTabs: tabs,
    );
    await tester.pumpWidget(
      MaterialApp(
        navigatorKey: navigatorKey,
        navigatorObservers: [observer],
        home: const SizedBox(),
      ),
    );

    expect(telemetry.screens, [TelemetryScreen.today]);
    tabs.value = RootTab.quiz;
    expect(telemetry.screens.last, TelemetryScreen.quizHub);

    navigatorKey.currentState!.push(
      MaterialPageRoute<void>(
        settings: const RouteSettings(name: '/events/private-event-id'),
        builder: (_) => const SizedBox(),
      ),
    );
    await tester.pumpAndSettle();
    expect(telemetry.screens.last, TelemetryScreen.eventDetail);

    navigatorKey.currentState!.push(
      MaterialPageRoute<void>(
        settings: const RouteSettings(name: '/quiz/results'),
        builder: (_) => const SizedBox(),
      ),
    );
    await tester.pumpAndSettle();
    expect(telemetry.screens.last, TelemetryScreen.results);

    navigatorKey.currentState!.pop();
    await tester.pumpAndSettle();
    expect(telemetry.screens.last, TelemetryScreen.eventDetail);
    tabs.dispose();
  });
}

final class _RecordingTelemetry implements AppTelemetry {
  final screens = <TelemetryScreen>[];

  @override
  void screenViewed(TelemetryScreen screen) => screens.add(screen);

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
