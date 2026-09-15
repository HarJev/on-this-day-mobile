import 'package:flutter/material.dart';

import '../../features/on_this_day/domain/on_this_day_repository.dart';
import '../../features/on_this_day/presentation/home_screen.dart';
import '../../features/quiz/domain/quiz_catalog.dart';
import '../../features/quiz/domain/quiz_result.dart';
import '../../features/quiz/presentation/quiz_hub_screen.dart';
import '../config/app_colors.dart';
import '../config/timezone_provider.dart';
import 'app_routes.dart';
import 'quiz_route_arguments.dart';
import 'quiz_route_dependencies.dart';

/// Retains Today and Quiz below focused pushed routes using one root navigator.
final class AppRootShell extends StatefulWidget {
  const AppRootShell({
    super.key,
    required this.onThisDayRepository,
    required this.timezoneProvider,
    required this.quizDependencies,
    required this.onShowDebugNotification,
  });

  final OnThisDayRepository onThisDayRepository;
  final TimezoneProvider timezoneProvider;
  final QuizRouteDependencies Function() quizDependencies;
  final VoidCallback? onShowDebugNotification;

  @override
  State<AppRootShell> createState() => _AppRootShellState();
}

class _AppRootShellState extends State<AppRootShell> {
  var _index = 0;
  var _quizCreated = false;
  String? _todayDate;
  QuizRouteDependencies? _quiz;

  void _select(int index) {
    if (index == 1 && !_quizCreated) {
      _quizCreated = true;
      _quiz = widget.quizDependencies();
    }
    setState(() => _index = index);
  }

  void _openDaily(QuizCatalog catalog) {
    Navigator.of(context).pushNamed(
      AppRoutes.dailySetup,
      arguments: DailySetupRouteArguments(catalog),
    );
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
              ),
            ),
        ],
      ),
      bottomNavigationBar: NavigationBar(
        selectedIndex: _index,
        onDestinationSelected: _select,
        destinations: const [
          NavigationDestination(
            icon: Icon(Icons.today_outlined),
            selectedIcon: Icon(Icons.today),
            label: 'Today',
          ),
          NavigationDestination(
            icon: Icon(Icons.quiz_outlined),
            selectedIcon: Icon(Icons.quiz),
            label: 'Quiz',
          ),
        ],
      ),
    );
  }

  AppBar _appBar() => AppBar(
    automaticallyImplyLeading: false,
    centerTitle: true,
    toolbarHeight: 48,
    title: Text(
      'On This Day',
      style: const TextStyle(
        fontFamily: 'Georgia',
        fontFamilyFallback: ['Times New Roman', 'serif'],
        fontSize: 24,
        color: AppColors.deepInk,
      ),
    ),
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
          child: Center(child: Text(_todayDate!)),
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
