import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:on_this_day_mobile/core/config/app_theme.dart';
import 'package:on_this_day_mobile/core/config/timezone_provider.dart';
import 'package:on_this_day_mobile/core/navigation/app_root_shell.dart';
import 'package:on_this_day_mobile/core/navigation/app_routes.dart';
import 'package:on_this_day_mobile/core/navigation/quiz_route_arguments.dart';
import 'package:on_this_day_mobile/core/navigation/quiz_route_dependencies.dart';
import 'package:on_this_day_mobile/core/navigation/source_launcher.dart';
import 'package:on_this_day_mobile/features/on_this_day/domain/daily_content.dart';
import 'package:on_this_day_mobile/features/on_this_day/domain/featured_event.dart';
import 'package:on_this_day_mobile/features/on_this_day/domain/historical_event.dart';
import 'package:on_this_day_mobile/features/on_this_day/domain/on_this_day_repository.dart';
import 'package:on_this_day_mobile/features/quiz/application/quiz_completion_coordinator.dart';
import 'package:on_this_day_mobile/features/quiz/application/quiz_completion_id_generator.dart';
import 'package:on_this_day_mobile/features/quiz/application/quiz_root_status.dart';
import 'package:on_this_day_mobile/features/quiz/application/quiz_session_launch_request.dart';
import 'package:on_this_day_mobile/features/quiz/domain/quiz_catalog.dart';
import 'package:on_this_day_mobile/features/quiz/domain/quiz_definition.dart';
import 'package:on_this_day_mobile/features/quiz/domain/quiz_repository.dart';
import 'package:on_this_day_mobile/features/quiz/domain/quiz_result.dart';
import 'package:on_this_day_mobile/features/quiz/domain/quiz_result_store.dart';
import 'package:on_this_day_mobile/features/quiz/domain/quiz_rules.dart';
import 'package:on_this_day_mobile/features/quiz/presentation/images/quiz_image_decoder.dart';
import 'package:on_this_day_mobile/features/quiz/presentation/images/quiz_image_downloader.dart';
import 'package:on_this_day_mobile/features/quiz/presentation/images/quiz_image_preparer.dart';

import '../../features/quiz/support/session_fakes.dart';

void main() {
  testWidgets('Hub Daily pushes one Ready route above the retained root', (
    tester,
  ) async {
    final harness = _Harness();
    await harness.pump(tester);
    await harness.openQuiz(tester);

    expect(harness.quiz.dailyCounts, [5]);
    expect(harness.dependencies.rootStatus.value?.displayDate, 'Sep 14');
    await tester.tap(find.text('10'));
    await tester.pump();
    await tester.tap(find.text('Continue with 10 questions'));
    await tester.pumpAndSettle();

    expect(harness.quiz.dailyCounts, [5, 10]);
    expect(harness.pushed, [AppRoutes.gameplay]);
    expect(find.text('Ready route'), findsOneWidget);
    expect(
      harness.launches.single.saveIntent,
      QuizSaveIntent.claimDailyIfAbsent,
    );
    expect(harness.quiz.catalogCalls, 1);

    harness.navigator.currentState!.popUntil(
      (route) => route.settings.name == AppRoutes.root,
    );
    await tester.pumpAndSettle();
    expect(find.text('Continue with 10 questions'), findsOneWidget);
    expect(harness.quiz.catalogCalls, 1);
  });

  testWidgets('a late Daily response does not push after leaving Quiz', (
    tester,
  ) async {
    final harness = _Harness();
    await harness.pump(tester);
    await harness.openQuiz(tester);

    final gate = Completer<void>();
    harness.quiz.hold = gate;
    await tester.tap(find.text('Continue with 5 questions'));
    await tester.pump();
    await tester.tap(find.byType(NavigationDestination).at(0));
    await tester.pump();
    gate.complete();
    await tester.pumpAndSettle();

    expect(harness.pushed, isEmpty);
    expect(tester.takeException(), isNull);
  });

  testWidgets('a late Daily response does not stack over Quick Play setup', (
    tester,
  ) async {
    final harness = _Harness();
    await harness.pump(tester);
    await harness.openQuiz(tester);

    final gate = Completer<void>();
    harness.quiz.hold = gate;
    await tester.tap(find.text('Continue with 5 questions'));
    await tester.pump();
    await tester.tap(find.text('Choose a round'));
    await tester.pumpAndSettle();
    gate.complete();
    await tester.pumpAndSettle();

    expect(harness.pushed, [AppRoutes.quickPlaySetup]);
  });
}

final class _Harness {
  final quiz = _QuizRepository();
  final store = _Store();
  final navigator = GlobalKey<NavigatorState>();
  final pushed = <String>[];
  final launches = <QuizSessionLaunchRequest>[];
  late final QuizRouteDependencies dependencies = QuizRouteDependencies(
    repository: quiz,
    resultStore: store,
    completionCoordinator: QuizCompletionCoordinator(store),
    imagePreparer: QuizImagePreparer(
      downloader: _NoopDownloader(),
      decoder: _NoopDecoder(),
    ),
    timezoneProvider: const _Timezone(),
    completionIdGenerator: const _Ids(),
    sourceLauncher: const PlatformSourceLauncher(),
    rootStatus: QuizRootStatus(),
  );

  Future<void> pump(WidgetTester tester) async {
    tester.view.physicalSize = const Size(800, 1600);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.light,
        navigatorKey: navigator,
        initialRoute: AppRoutes.root,
        onGenerateRoute: (settings) {
          if (settings.name == AppRoutes.root) {
            return MaterialPageRoute<void>(
              settings: settings,
              builder: (_) => AppRootShell(
                onThisDayRepository: _TodayRepository(),
                timezoneProvider: const _Timezone(),
                quizDependencies: () => dependencies,
                onShowDebugNotification: null,
              ),
            );
          }
          pushed.add(settings.name!);
          if (settings.arguments case GameplayRouteArguments(:final launch)) {
            launches.add(launch);
          }
          return MaterialPageRoute<void>(
            settings: settings,
            builder: (_) => Scaffold(
              body: Text(
                settings.name == AppRoutes.gameplay
                    ? 'Ready route'
                    : 'Other route',
              ),
            ),
          );
        },
      ),
    );
    await tester.pumpAndSettle();
  }

  Future<void> openQuiz(WidgetTester tester) async {
    await tester.tap(find.byType(NavigationDestination).at(1));
    await tester.pumpAndSettle();
  }
}

final class _QuizRepository implements QuizRepository {
  int catalogCalls = 0;
  final dailyCounts = <int>[];
  Completer<void>? hold;

  @override
  Future<QuizCatalog> getCatalog() async {
    catalogCalls++;
    return QuizCatalog(
      mixed: QuizAvailability(
        publishedQuestionCount: 20,
        supportedQuestionCounts: QuizRules.questionCounts,
      ),
      collections: const [],
      quickPlayTimerDefaults: QuizRules.quickPlayDefaults,
    );
  }

  @override
  Future<DailyQuizDefinition> getDaily({
    required String timezone,
    required int questionCount,
  }) async {
    dailyCounts.add(questionCount);
    final gate = hold;
    hold = null;
    if (gate != null) await gate.future;
    return DailyQuizDefinition(
      questionCount: 5,
      questions: sessionQuestions(),
      challengeId: 'daily-2026-09-14',
      date: QuizDate('2026-09-14'),
      displayDate: 'Sep 14',
      duration: const Duration(minutes: 2),
    );
  }

  @override
  Future<QuickPlayQuizDefinition> createQuickPlay({
    required int questionCount,
    String? collectionId,
  }) => throw UnimplementedError();
}

final class _TodayRepository implements OnThisDayRepository {
  @override
  Future<DailyContent> getTodayContent(String timezone) async => DailyContent(
    displayDate: 'Sep 14',
    featuredEvent: const FeaturedEvent(
      id: 'test-event',
      title: 'Test event',
      year: '1900',
      historicalDate: 'September 14, 1900',
      summary: 'A short test summary.',
      notificationTitle: 'Test',
      notificationBody: 'Test',
    ),
    additionalEvents: const [],
  );

  @override
  Future<HistoricalEvent> getEvent(String eventId) =>
      throw UnimplementedError();
}

final class _Store implements QuizResultStore {
  @override
  Future<StoredQuizResult?> getBestResult(QuizBestResultKey key) async => null;
  @override
  Future<StoredQuizResult?> getOfficialDaily(QuizDate date) async => null;
  @override
  Future<bool> getQuickPlayTimingEnabled() async => true;
  @override
  Future<StoredQuizResult> saveCompletion(QuizCompletion completion) =>
      throw UnimplementedError();
  @override
  Future<void> setQuickPlayTimingEnabled(bool enabled) async {}
}

final class _Timezone implements TimezoneProvider {
  const _Timezone();
  @override
  Future<String> currentTimezone() async => 'Etc/UTC';
}

final class _Ids implements QuizCompletionIdGenerator {
  const _Ids();
  @override
  String nextId() => 'test-completion';
}

final class _NoopDownloader implements QuizImageDownloader {
  @override
  Future<Never> download(
    Uri url,
    dynamic cancellation, {
    required int maxBytes,
    required void Function(int) reserveBytes,
    DateTime? deadline,
  }) => throw UnimplementedError();
}

final class _NoopDecoder implements QuizImageDecoder {
  @override
  Future<Never> decode(
    dynamic bytes,
    dynamic cancellation, {
    required int maxEdge,
    required void Function(int) reserveDecodedBytes,
  }) => throw UnimplementedError();
}
