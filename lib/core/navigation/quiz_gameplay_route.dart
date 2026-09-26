import 'dart:async';

import 'package:flutter/material.dart';

import '../../features/quiz/application/quiz_session_launch_request.dart';
import '../../features/quiz/presentation/quiz_gameplay_view.dart';
import '../../features/quiz/presentation/quiz_session_clock.dart';
import '../../features/quiz/presentation/quiz_session_controller.dart';
import '../../features/quiz/presentation/quiz_session_scheduler.dart';
import 'quiz_route_dependencies.dart';

/// Owns one playable session for a pushed route. Persistence stays with the
/// app-scoped completion coordinator supplied through [dependencies].
final class QuizGameplayRoute extends StatefulWidget {
  const QuizGameplayRoute({
    super.key,
    required this.launch,
    required this.dependencies,
    required this.routeObserver,
    required this.onExit,
    required this.onResults,
  });

  final QuizSessionLaunchRequest launch;
  final QuizRouteDependencies dependencies;
  final RouteObserver<PageRoute<dynamic>> routeObserver;
  final VoidCallback onExit;
  final ValueChanged<String> onResults;

  @override
  State<QuizGameplayRoute> createState() => _QuizGameplayRouteState();
}

class _QuizGameplayRouteState extends State<QuizGameplayRoute>
    with WidgetsBindingObserver, RouteAware {
  late final QuizSessionController _controller;
  PageRoute<dynamic>? _route;
  var _disposed = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _controller = QuizSessionController(
      definition: widget.launch.definition,
      completionId: widget.launch.completionId,
      timingEnabled: widget.launch.timingEnabled,
      clock: StopwatchQuizSessionClock(),
      scheduler: TimerQuizSessionScheduler(),
      prepareSession: widget.dependencies.imagePreparer.call,
      completionSink: widget.dependencies.completionCoordinator.sinkFor(
        widget.launch.saveIntent,
      ),
    );
    unawaited(_controller.prepare());
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final route = ModalRoute.of(context);
    if (route is PageRoute<dynamic> && _route != route) {
      if (_route != null) widget.routeObserver.unsubscribe(this);
      _route = route;
      widget.routeObserver.subscribe(this, route);
    }
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (_disposed) return;
    _controller.setAppActive(state == AppLifecycleState.resumed);
  }

  @override
  void didPushNext() => _controller.setRouteVisible(false);

  @override
  void didPopNext() => _controller.setRouteVisible(true);

  @override
  void dispose() {
    _disposed = true;
    WidgetsBinding.instance.removeObserver(this);
    if (_route != null) widget.routeObserver.unsubscribe(this);
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => QuizGameplayView(
    controller: _controller,
    sourceLauncher: widget.dependencies.sourceLauncher,
    onExit: widget.onExit,
    onViewResults: (result) {
      if (_disposed) return;
      _controller.releaseCompletedImages();
      widget.onResults(result.completionId);
    },
  );
}
