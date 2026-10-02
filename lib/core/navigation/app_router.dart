import 'package:flutter/material.dart';

import '../images/cached_optional_image_loader.dart';
import '../../features/on_this_day/domain/on_this_day_repository.dart';
import '../../features/on_this_day/presentation/event_detail_screen.dart';
import '../../features/on_this_day/presentation/home_screen.dart';
import '../../features/quiz/presentation/daily_challenge_setup_screen.dart';
import '../../features/quiz/presentation/quick_play_setup_screen.dart';
import '../../features/quiz/presentation/quiz_full_review_screen.dart';
import '../../features/quiz/presentation/quiz_results_screen.dart';
import '../config/timezone_provider.dart';
import '../notifications/notification_prompt_coordinator.dart';
import '../telemetry/app_telemetry.dart';
import 'app_root_shell.dart';
import 'app_routes.dart';
import 'event_detail_route_arguments.dart';
import 'quiz_gameplay_route.dart';
import 'quiz_route_arguments.dart';
import 'quiz_route_dependencies.dart';
import 'root_tab_controller.dart';
import 'source_launcher.dart';

class AppRouter {
  AppRouter({
    required OnThisDayRepository repository,
    required TimezoneProvider timezoneProvider,
    SourceLauncher sourceLauncher = const PlatformSourceLauncher(),
    VoidCallback? onShowDebugNotification,
    QuizRouteDependencies Function()? quizDependencies,
    RouteObserver<PageRoute<dynamic>>? routeObserver,
    GlobalKey<NavigatorState>? navigatorKey,
    OptionalImageLoader? optionalImageLoader,
    NotificationPromptCoordinator? notificationPrompt,
    RootTabController? rootTabs,
    AppTelemetry telemetry = const NoopAppTelemetry(),
  }) : _repository = repository,
       _timezoneProvider = timezoneProvider,
       _sourceLauncher = sourceLauncher,
       _onShowDebugNotification = onShowDebugNotification,
       _quizDependencies = quizDependencies,
       _navigatorKey = navigatorKey,
       _optionalImageLoader = optionalImageLoader,
       _notificationPrompt = notificationPrompt,
       _telemetry = telemetry,
       rootTabs = rootTabs ?? RootTabController(),
       routeObserver = routeObserver ?? RouteObserver<PageRoute<dynamic>>();

  final OnThisDayRepository _repository;
  final TimezoneProvider _timezoneProvider;
  final SourceLauncher _sourceLauncher;
  final VoidCallback? _onShowDebugNotification;
  final QuizRouteDependencies Function()? _quizDependencies;
  final GlobalKey<NavigatorState>? _navigatorKey;
  final OptionalImageLoader? _optionalImageLoader;
  final NotificationPromptCoordinator? _notificationPrompt;
  final AppTelemetry _telemetry;
  final RouteObserver<PageRoute<dynamic>> routeObserver;
  final RootTabController rootTabs;

  Route<void> onGenerateRoute(RouteSettings settings) {
    final routeName = settings.name ?? AppRoutes.today;
    final uri = Uri.parse(routeName);

    if (_isRootRoute(uri) && _quizDependencies != null) {
      return _page(
        AppRootShell(
          onThisDayRepository: _repository,
          timezoneProvider: _timezoneProvider,
          quizDependencies: _quizDependencies,
          onShowDebugNotification: _onShowDebugNotification,
          optionalImageLoader: _optionalImageLoader,
          sourceLauncher: _sourceLauncher,
          rootTabs: rootTabs,
          telemetry: _telemetry,
        ),
        settings,
      );
    }

    if (_isTodayRoute(uri)) {
      return _page(
        HomeScreen(
          repository: _repository,
          timezoneProvider: _timezoneProvider,
          onShowDebugNotification: _onShowDebugNotification,
          imageLoader: _optionalImageLoader,
          sourceLauncher: _sourceLauncher,
          telemetry: _telemetry,
        ),
        settings,
      );
    }

    final eventId = _eventIdFrom(uri);
    if (eventId != null) {
      final args = settings.arguments;
      final offersQuiz =
          _quizDependencies != null &&
          args is EventDetailRouteArguments &&
          args.isToday;
      return _page(
        EventDetailScreen(
          repository: _repository,
          eventId: eventId,
          sourceLauncher: _sourceLauncher,
          imageLoader: _optionalImageLoader,
          notificationPrompt: _notificationPrompt,
          onTestWhatYouLearned: offersQuiz ? _openQuizTab : null,
        ),
        settings,
      );
    }

    final quiz = _isQuizRoute(uri) ? _quizDependencies?.call() : null;
    if (quiz != null && uri.path == AppRoutes.dailySetup) {
      final args = settings.arguments;
      if (args is! DailySetupRouteArguments) return _unavailable(settings);
      return _page(
        DailyChallengeSetupScreen(
          repository: quiz.repository,
          timezoneProvider: quiz.timezoneProvider,
          resultStore: quiz.resultStore,
          completionCoordinator: quiz.completionCoordinator,
          completionIdGenerator: quiz.completionIdGenerator,
          availability: args.catalog.mixed,
          onStatusResolved: quiz.rootStatus.update,
          onLaunch: (launch) => _navigator!.pushReplacementNamed(
            AppRoutes.gameplay,
            arguments: GameplayRouteArguments(launch),
          ),
          onBack: _returnToRoot,
        ),
        settings,
      );
    }

    if (quiz != null && uri.path == AppRoutes.quickPlaySetup) {
      final args = settings.arguments;
      if (args is! QuickPlaySetupRouteArguments) return _unavailable(settings);
      return _page(
        QuickPlaySetupScreen(
          repository: quiz.repository,
          resultStore: quiz.resultStore,
          completionIdGenerator: quiz.completionIdGenerator,
          catalog: args.catalog,
          onLaunch: (launch) => _navigator!.pushReplacementNamed(
            AppRoutes.gameplay,
            arguments: GameplayRouteArguments(launch),
          ),
          onBack: _returnToRoot,
        ),
        settings,
      );
    }

    if (quiz != null && uri.path == AppRoutes.gameplay) {
      final args = settings.arguments;
      if (args is! GameplayRouteArguments) return _unavailable(settings);
      return _page(
        QuizGameplayRoute(
          launch: args.launch,
          dependencies: quiz,
          telemetry: _telemetry,
          routeObserver: routeObserver,
          onExit: _returnToRoot,
          onResults: (completionId) => _navigator!.pushReplacementNamed(
            AppRoutes.results,
            arguments: ResultsRouteArguments(completionId),
          ),
        ),
        settings,
      );
    }

    if (quiz != null && uri.path == AppRoutes.results) {
      final args = settings.arguments;
      if (args is! ResultsRouteArguments || args.completionId.trim().isEmpty) {
        return _unavailable(settings);
      }
      return _page(
        QuizResultsScreen(
          coordinator: quiz.completionCoordinator,
          completionId: args.completionId,
          onOpenEvent: (id) => _navigator!.pushNamed(AppRoutes.eventDetail(id)),
          onReview: (result) => _navigator!.pushNamed(
            AppRoutes.review,
            arguments: ReviewRouteArguments(result),
          ),
          onDone: _returnToRoot,
        ),
        settings,
      );
    }

    if (quiz != null && uri.path == AppRoutes.review) {
      final args = settings.arguments;
      if (args is! ReviewRouteArguments) return _unavailable(settings);
      return _page(
        QuizFullReviewScreen(
          result: args.result,
          onOpenEvent: (id) => _navigator!.pushNamed(AppRoutes.eventDetail(id)),
          sourceLauncher: quiz.sourceLauncher,
          imageLoader: _optionalImageLoader,
          onDone: () => _navigator?.pop(),
        ),
        settings,
      );
    }

    return _unavailable(settings);
  }

  bool _isTodayRoute(Uri uri) {
    return _isRootRoute(uri) ||
        (uri.pathSegments.length == 1 && uri.pathSegments.first == 'today');
  }

  bool _isRootRoute(Uri uri) => uri.path == AppRoutes.root;

  bool _isQuizRoute(Uri uri) => switch (uri.path) {
    AppRoutes.dailySetup ||
    AppRoutes.quickPlaySetup ||
    AppRoutes.gameplay ||
    AppRoutes.results ||
    AppRoutes.review => true,
    _ => false,
  };

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

  Route<void> _unavailable(RouteSettings settings) =>
      _page(const UnavailableRouteScreen(), settings);

  NavigatorState? get _navigator => _navigatorKey?.currentState;

  void _openQuizTab() {
    rootTabs.value = RootTab.quiz;
    _returnToRoot();
  }

  void _returnToRoot() =>
      _navigator?.popUntil((route) => route.settings.name == AppRoutes.root);
}

class UnavailableRouteScreen extends StatelessWidget {
  const UnavailableRouteScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('On This Day')),
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text('Content unavailable'),
              const SizedBox(height: 16),
              FilledButton(
                onPressed: () => Navigator.of(
                  context,
                ).pushNamedAndRemoveUntil(AppRoutes.root, (_) => false),
                child: const Text('Go to Today'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
