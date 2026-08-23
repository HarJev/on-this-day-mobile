import 'package:flutter/material.dart';

import 'app_routes.dart';

class AppRouter {
  const AppRouter();

  Route<void> onGenerateRoute(RouteSettings settings) {
    final routeName = settings.name ?? AppRoutes.today;
    final uri = Uri.parse(routeName);

    if (_isTodayRoute(uri)) {
      return _page(const TodayPlaceholderScreen(), settings);
    }

    final eventId = _eventIdFrom(uri);
    if (eventId != null) {
      return _page(EventDetailPlaceholderScreen(eventId: eventId), settings);
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

class TodayPlaceholderScreen extends StatelessWidget {
  const TodayPlaceholderScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('On This Day')),
      body: const Center(child: Text('Today')),
    );
  }
}

class EventDetailPlaceholderScreen extends StatelessWidget {
  const EventDetailPlaceholderScreen({super.key, required this.eventId})
    : assert(eventId != '');

  final String eventId;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('On This Day')),
      body: Center(child: Text('Event: $eventId')),
    );
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
