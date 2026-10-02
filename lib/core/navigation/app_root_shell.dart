import 'package:flutter/material.dart';

import '../../features/on_this_day/domain/on_this_day_repository.dart';
import '../../features/on_this_day/presentation/home_screen.dart';
import '../../features/quiz/application/quiz_session_launch_request.dart';
import '../../features/quiz/domain/quiz_catalog.dart';
import '../../features/quiz/domain/quiz_result.dart';
import '../../features/quiz/presentation/daily_challenge_setup_controller.dart';
import '../../features/quiz/presentation/quiz_hub_screen.dart';
import '../images/cached_optional_image_loader.dart';
import '../config/app_colors.dart';
import '../config/app_theme.dart';
import '../config/timezone_provider.dart';
import '../telemetry/app_telemetry.dart';
import 'app_routes.dart';
import 'quiz_route_arguments.dart';
import 'quiz_route_dependencies.dart';
import 'root_tab_controller.dart';
import 'source_launcher.dart';

/// Retains Today and Quiz below focused pushed routes using one root navigator.
final class AppRootShell extends StatefulWidget {
  const AppRootShell({
    super.key,
    required this.onThisDayRepository,
    required this.timezoneProvider,
    required this.quizDependencies,
    required this.onShowDebugNotification,
    this.optionalImageLoader,
    this.sourceLauncher = const PlatformSourceLauncher(),
    this.rootTabs,
    this.telemetry = const NoopAppTelemetry(),
  });

  final OnThisDayRepository onThisDayRepository;
  final TimezoneProvider timezoneProvider;
  final QuizRouteDependencies Function() quizDependencies;
  final VoidCallback? onShowDebugNotification;
  final OptionalImageLoader? optionalImageLoader;
  final SourceLauncher sourceLauncher;
  final AppTelemetry telemetry;

  /// When provided, routes above the shell can switch the visible tab.
  final RootTabController? rootTabs;

  @override
  State<AppRootShell> createState() => _AppRootShellState();
}

class _AppRootShellState extends State<AppRootShell> {
  var _index = 0;
  var _quizCreated = false;
  String? _todayDate;
  QuizRouteDependencies? _quiz;

  @override
  void initState() {
    super.initState();
    widget.rootTabs?.addListener(_followRootTabs);
  }

  @override
  void didUpdateWidget(AppRootShell oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.rootTabs != widget.rootTabs) {
      oldWidget.rootTabs?.removeListener(_followRootTabs);
      widget.rootTabs?.addListener(_followRootTabs);
    }
  }

  @override
  void dispose() {
    widget.rootTabs?.removeListener(_followRootTabs);
    super.dispose();
  }

  void _followRootTabs() {
    final tab = widget.rootTabs?.value;
    if (tab != null && tab.index != _index) _select(tab.index);
  }

  void _select(int index) {
    if (index == 1 && !_quizCreated) {
      _quizCreated = true;
      _quiz = widget.quizDependencies();
    }
    setState(() => _index = index);
    final tabs = widget.rootTabs;
    if (tabs != null) tabs.value = RootTab.values[index];
  }

  void _openDaily(QuizCatalog catalog) {
    Navigator.of(context).pushNamed(
      AppRoutes.dailySetup,
      arguments: DailySetupRouteArguments(catalog),
    );
  }

  /// Pushes the Ready route above the retained root, but only while Quiz is
  /// visible and no other route has been opened during the Daily request.
  void _launchDaily(QuizSessionLaunchRequest launch) {
    if (!mounted || _index != 1 || ModalRoute.of(context)?.isCurrent == false) {
      return;
    }
    Navigator.of(
      context,
    ).pushNamed(AppRoutes.gameplay, arguments: GameplayRouteArguments(launch));
  }

  void _openQuick(QuizCatalog catalog) {
    Navigator.of(context).pushNamed(
      AppRoutes.quickPlaySetup,
      arguments: QuickPlaySetupRouteArguments(catalog),
    );
  }

  void _openReview(QuizResult result) {
    Navigator.of(
      context,
    ).pushNamed(AppRoutes.review, arguments: ReviewRouteArguments(result));
  }

  @override
  Widget build(BuildContext context) {
    final quiz = _quiz;
    return Scaffold(
      appBar: _appBar(),
      body: IndexedStack(
        index: _index,
        children: [
          HomeScreen(
            repository: widget.onThisDayRepository,
            timezoneProvider: widget.timezoneProvider,
            imageLoader: widget.optionalImageLoader,
            sourceLauncher: widget.sourceLauncher,
            telemetry: widget.telemetry,
            embedded: true,
            onDisplayDateChanged: (date) {
              if (mounted && date != _todayDate) {
                setState(() => _todayDate = date);
              }
            },
          ),
          if (quiz == null)
            const SizedBox.shrink()
          else
            ValueListenableBuilder(
              valueListenable: quiz.rootStatus,
              builder: (context, status, _) => QuizHubScreen(
                repository: quiz.repository,
                embedded: true,
                dailyStatus: status,
                onOpenDaily: _openDaily,
                onOpenQuickPlay: _openQuick,
                onReviewDailyResult: _openReview,
                createDailySetup: (availability) =>
                    DailyChallengeSetupController(
                      repository: quiz.repository,
                      timezoneProvider: quiz.timezoneProvider,
                      resultStore: quiz.resultStore,
                      completionCoordinator: quiz.completionCoordinator,
                      completionIdGenerator: quiz.completionIdGenerator,
                      availability: availability,
                    ),
                onLaunchDaily: _launchDaily,
                onDailyStatusResolved: quiz.rootStatus.update,
              ),
            ),
        ],
      ),
      bottomNavigationBar: DecoratedBox(
        decoration: const BoxDecoration(
          border: Border(top: BorderSide(color: AppColors.paleStone)),
        ),
        child: NavigationBar(
          selectedIndex: _index,
          onDestinationSelected: _select,
          destinations: const [
            NavigationDestination(
              icon: Icon(Icons.menu_book_outlined),
              selectedIcon: Icon(Icons.menu_book),
              label: 'Today',
            ),
            NavigationDestination(
              icon: Icon(Icons.quiz_outlined),
              selectedIcon: Icon(Icons.quiz),
              label: 'Quiz',
            ),
          ],
        ),
      ),
    );
  }

  AppBar _appBar() => AppBar(
    automaticallyImplyLeading: false,
    centerTitle: true,
    toolbarHeight: 56,
    title: const Text('On This Day', style: AppText.masthead),
    actions: [
      if (_index == 0 && widget.onShowDebugNotification != null)
        IconButton(
          tooltip: 'Show test notification',
          onPressed: widget.onShowDebugNotification,
          icon: const Icon(Icons.notifications_outlined),
        ),
      if (_index == 0 && _todayDate != null)
        Padding(
          padding: const EdgeInsets.only(right: 20),
          child: Center(
            child: Text(
              _todayDate!,
              style: Theme.of(
                context,
              ).textTheme.labelLarge?.copyWith(fontSize: 14),
            ),
          ),
        ),
    ],
    bottom: const PreferredSize(
      preferredSize: Size.fromHeight(1),
      child: ColoredBox(
        color: AppColors.paleStone,
        child: SizedBox(height: 1, width: double.infinity),
      ),
    ),
  );
}
