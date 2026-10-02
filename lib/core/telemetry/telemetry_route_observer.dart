import 'package:flutter/material.dart';

import '../navigation/app_routes.dart';
import '../navigation/root_tab_controller.dart';
import 'app_telemetry.dart';

/// Maps navigation to a fixed vocabulary; event IDs and route arguments never
/// reach telemetry.
final class TelemetryRouteObserver extends NavigatorObserver {
  TelemetryRouteObserver({
    required AppTelemetry telemetry,
    required RootTabController rootTabs,
  }) : _telemetry = telemetry,
       _rootTabs = rootTabs {
    _rootTabs.addListener(_onTabChanged);
  }

  final AppTelemetry _telemetry;
  final RootTabController _rootTabs;

  @override
  void didPush(Route<dynamic> route, Route<dynamic>? previousRoute) =>
      _record(route);

  @override
  void didPop(Route<dynamic> route, Route<dynamic>? previousRoute) {
    if (previousRoute != null) _record(previousRoute);
  }

  void _onTabChanged() {
    _telemetry.screenViewed(
      _rootTabs.value == RootTab.today
          ? TelemetryScreen.today
          : TelemetryScreen.quizHub,
    );
  }

  void _record(Route<dynamic> route) {
    final name = route.settings.name;
    if (name == null) return;
    final screen = switch (Uri.tryParse(name)?.path) {
      AppRoutes.root || AppRoutes.today =>
        _rootTabs.value == RootTab.today
            ? TelemetryScreen.today
            : TelemetryScreen.quizHub,
      AppRoutes.dailySetup => TelemetryScreen.dailySetup,
      AppRoutes.quickPlaySetup => TelemetryScreen.quickPlaySetup,
      AppRoutes.gameplay => TelemetryScreen.gameplay,
      AppRoutes.results => TelemetryScreen.results,
      AppRoutes.review => TelemetryScreen.review,
      final path? when path.startsWith('${AppRoutes.eventsPrefix}/') =>
        TelemetryScreen.eventDetail,
      _ => null,
    };
    if (screen != null) _telemetry.screenViewed(screen);
  }
}
