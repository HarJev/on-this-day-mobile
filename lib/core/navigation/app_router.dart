import 'package:flutter/material.dart';

import '../../features/on_this_day/domain/on_this_day_repository.dart';
import '../../features/on_this_day/presentation/event_detail_screen.dart';
import '../../features/on_this_day/presentation/home_screen.dart';
import '../config/timezone_provider.dart';
import 'app_routes.dart';
import 'source_launcher.dart';

class AppRouter {
  const AppRouter({
    required OnThisDayRepository repository,
    required TimezoneProvider timezoneProvider,
    SourceLauncher sourceLauncher = const PlatformSourceLauncher(),
    VoidCallback? onShowDebugNotification,
  }) : _repository = repository,
       _timezoneProvider = timezoneProvider,
       _sourceLauncher = sourceLauncher,
       _onShowDebugNotification = onShowDebugNotification;

  final OnThisDayRepository _repository;
  final TimezoneProvider _timezoneProvider;
  final SourceLauncher _sourceLauncher;
  final VoidCallback? _onShowDebugNotification;

  Route<void> onGenerateRoute(RouteSettings settings) {
    final routeName = settings.name ?? AppRoutes.today;
    final uri = Uri.parse(routeName);

    if (_isTodayRoute(uri)) {
      return _page(
        HomeScreen(
          repository: _repository,
          timezoneProvider: _timezoneProvider,
          onShowDebugNotification: _onShowDebugNotification,
        ),
        settings,
      );
    }

    final eventId = _eventIdFrom(uri);
    if (eventId != null) {
      return _page(
        EventDetailScreen(
          repository: _repository,
          eventId: eventId,
          sourceLauncher: _sourceLauncher,
        ),
        settings,
      );
    }

    return _page(const UnavailableRouteScreen(), settings);
  }

  bool _isTodayRoute(Uri uri) {
    return uri.pathSegments.length == 1 && uri.pathSegments.first == 'today';
  }

  String? _eventIdFrom(Uri uri) {
    if (uri.pathSegments.length != 2 || uri.pathSegments.first != 'events') {
      return null;
    }

    final eventId = uri.pathSegments.last;
    if (eventId.isEmpty) {
      return null;
    }

    return eventId;
  }

  MaterialPageRoute<void> _page(Widget child, RouteSettings settings) {
    return MaterialPageRoute<void>(builder: (_) => child, settings: settings);
  }
}

class UnavailableRouteScreen extends StatelessWidget {
  const UnavailableRouteScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('On This Day')),
      body: const Center(child: Text('Content unavailable')),
    );
  }
}
