import 'dart:async';
import 'dart:convert';
import 'package:on_this_day_mobile/features/quiz/data/local/quiz_result_snapshot_codec.dart';
import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:on_this_day_mobile/core/config/app_theme.dart';
import 'package:on_this_day_mobile/core/config/timezone_provider.dart';
import 'package:on_this_day_mobile/core/navigation/app_root_shell.dart';
import 'package:on_this_day_mobile/core/navigation/app_router.dart';
import 'package:on_this_day_mobile/core/navigation/app_routes.dart';
import 'package:on_this_day_mobile/core/navigation/quiz_route_arguments.dart';
import 'package:on_this_day_mobile/core/navigation/quiz_route_dependencies.dart';
import 'package:on_this_day_mobile/core/navigation/root_tab_controller.dart';
import 'package:on_this_day_mobile/core/navigation/source_launcher.dart';
import 'package:on_this_day_mobile/features/on_this_day/domain/daily_content.dart';
import 'package:on_this_day_mobile/features/on_this_day/domain/event_source.dart';
import 'package:on_this_day_mobile/features/on_this_day/domain/featured_event.dart';
import 'package:on_this_day_mobile/features/on_this_day/domain/historical_event.dart';
import 'package:on_this_day_mobile/features/on_this_day/domain/on_this_day_repository.dart';
import 'package:on_this_day_mobile/features/on_this_day/domain/recent_day.dart';
import 'package:on_this_day_mobile/features/quiz/application/daily_challenge_status.dart';
import 'package:on_this_day_mobile/features/quiz/application/quiz_completion_coordinator.dart';
import 'package:on_this_day_mobile/features/quiz/application/quiz_completion_id_generator.dart';
import 'package:on_this_day_mobile/features/quiz/application/quiz_root_status.dart';
import 'package:on_this_day_mobile/features/quiz/domain/question_outcome.dart';
import 'package:on_this_day_mobile/features/quiz/domain/quiz_answer.dart';
import 'package:on_this_day_mobile/features/quiz/domain/quiz_catalog.dart';
import 'package:on_this_day_mobile/features/quiz/domain/quiz_definition.dart';
import 'package:on_this_day_mobile/features/quiz/domain/quiz_question.dart';
import 'package:on_this_day_mobile/features/quiz/domain/quiz_repository.dart';
import 'package:on_this_day_mobile/features/quiz/domain/quiz_result.dart';
import 'package:on_this_day_mobile/features/quiz/domain/quiz_result_store.dart';
import 'package:on_this_day_mobile/features/quiz/domain/quiz_rules.dart';
import 'package:on_this_day_mobile/features/quiz/presentation/images/quiz_image_decoder.dart';
import 'package:on_this_day_mobile/features/quiz/presentation/images/quiz_image_downloader.dart';
import 'package:on_this_day_mobile/features/quiz/presentation/images/quiz_image_preparer.dart';
import 'package:on_this_day_mobile/features/quiz/presentation/quiz_full_review_screen.dart';
import 'package:on_this_day_mobile/features/quiz/presentation/quiz_results_screen.dart';

import '../../features/quiz/support/session_fakes.dart';
import '../../support/capture_fonts.dart';

void main() {
  testWidgets(
    'pending Results can review a related story without changing its frozen result',
    (tester) async {
      final dependencies = _dependencies(_QuizRepository(), _ControlledStore());
      final navigator = await _pumpRoutedShell(tester, dependencies);
      const codec = QuizResultSnapshotCodec();
      final snapshot =
          jsonDecode(codec.encode(_dailyClaim('related-results').result))
              as Map<String, dynamic>;
      snapshot['definition']['questions'][0]['relatedEvents'] = [
        {'id': 'linked-story', 'title': 'Test event', 'year': '1900'},
      ];
      snapshot['outcomes'][0]['kind'] = 'incorrect';
      snapshot['outcomes'][0]['answer']['optionId'] = 'b';
      final result = codec.decode(jsonEncode(snapshot));
      await _finishDailyAndOpenResults(
        tester,
        navigator,
        dependencies,
        QuizCompletion(result, QuizSaveIntent.claimDailyIfAbsent),
      );
      await tester.tap(find.text('Review answers'));
      await tester.pumpAndSettle();
      final disclosure = find.byKey(const ValueKey('q-0:related-history'));
      await tester.ensureVisible(disclosure);
      await tester.pumpAndSettle();
      await tester.tap(
        find.descendant(of: disclosure, matching: find.text('Related history')),
      );
      await tester.pumpAndSettle();
      final link = find.byKey(const ValueKey('related-event-linked-story'));
      await tester.ensureVisible(link);
      await tester.pumpAndSettle();
      await tester.tap(link);
      await tester.pumpAndSettle();
      expect(find.text('Test event'), findsOneWidget);
      navigator.currentState!.pop();
      await tester.pumpAndSettle();
      expect(link, findsOneWidget);
      expect(
        identical(
          dependencies.completionCoordinator
              .stateFor(result.completionId)!
              .completion
              .result,
          result,
        ),
        isTrue,
      );
    },
  );

  testWidgets(
    'production Review opens Event Detail and back retains the expanded story',
    (tester) async {
      final dependencies = _dependencies(_QuizRepository(), _Store());
      final navigator = await _pumpRoutedShell(tester, dependencies);
      const codec = QuizResultSnapshotCodec();
      final snapshot =
          jsonDecode(codec.encode(_dailyClaim('related-review').result))
              as Map<String, dynamic>;
      snapshot['definition']['questions'][0]['relatedEvents'] = [
        {'id': 'linked-story', 'title': 'Test event', 'year': '1900'},
      ];
      final result = codec.decode(jsonEncode(snapshot));
      unawaited(
        navigator.currentState!.pushNamed(
          AppRoutes.review,
          arguments: ReviewRouteArguments(result),
        ),
      );
      await tester.pumpAndSettle();
      final disclosure = find.byKey(const ValueKey('q-0:related-history'));
      await tester.ensureVisible(disclosure);
      await tester.pumpAndSettle();
      await tester.tap(
        find.descendant(of: disclosure, matching: find.text('Related history')),
      );
      await tester.pumpAndSettle();
      final link = find.byKey(const ValueKey('related-event-linked-story'));
      await tester.ensureVisible(link);
      await tester.pumpAndSettle();
      await tester.tap(link);
      await tester.pumpAndSettle();
      expect(find.text('Test event'), findsOneWidget);
      expect(find.text("Explore today's quiz"), findsNothing);
      navigator.currentState!.pop();
      await tester.pumpAndSettle();
      expect(link, findsOneWidget);
      expect(find.text('Full review'), findsOneWidget);
    },
  );

  testWidgets('creates and loads Quiz only after first root selection', (
    tester,
  ) async {
    final quizRepository = _QuizRepository();
    var factoryCalls = 0;
    final dependencies = _dependencies(quizRepository, _Store());
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.light,
        home: AppRootShell(
          onThisDayRepository: _TodayRepository(),
          timezoneProvider: const _Timezone(),
          quizDependencies: () {
            factoryCalls++;
            return dependencies;
          },
          onShowDebugNotification: () {},
        ),
      ),
    );
    await tester.pump();

    expect(factoryCalls, 0);
    expect(quizRepository.catalogCalls, 0);
    expect(find.text('Today'), findsOneWidget);
    expect(find.byTooltip('Show test notification'), findsOneWidget);

    await tester.tap(find.byType(NavigationDestination).at(1));
    await tester.pumpAndSettle();

    expect(factoryCalls, 1);
    expect(quizRepository.catalogCalls, 1);
    expect(find.text('Sep 13'), findsOneWidget);
    expect(find.byTooltip('Show test notification'), findsNothing);

    await tester.tap(find.byType(NavigationDestination).at(0));
    await tester.tap(find.byType(NavigationDestination).at(1));
    await tester.pumpAndSettle();
    expect(factoryCalls, 1);
    expect(quizRepository.catalogCalls, 1);
  });

  testWidgets('Explore the daily quiz returns to the Quiz tab', (tester) async {
    final quizRepository = _QuizRepository();
    final navigatorKey = GlobalKey<NavigatorState>();
    final router = AppRouter(
      repository: _TodayRepository(),
      timezoneProvider: const _Timezone(),
      quizDependencies: () => _dependencies(quizRepository, _Store()),
      navigatorKey: navigatorKey,
    );
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.light,
        navigatorKey: navigatorKey,
        onGenerateRoute: router.onGenerateRoute,
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.text('Test event'));
    await tester.pumpAndSettle();
    await tester.scrollUntilVisible(find.text("Explore today's quiz"), 200);
    await tester.tap(find.text("Explore today's quiz"));
    await tester.pumpAndSettle();

    expect(find.text("Explore today's quiz"), findsNothing);
    final bar = tester.widget<NavigationBar>(find.byType(NavigationBar));
    expect(bar.selectedIndex, 1);
    expect(quizRepository.catalogCalls, 1);

    await tester.tap(find.byType(NavigationDestination).at(0));
    await tester.pumpAndSettle();
    expect(
      tester.widget<NavigationBar>(find.byType(NavigationBar)).selectedIndex,
      0,
    );
    expect(router.rootTabs.value, RootTab.today);
  });

  testWidgets('representative retained-shell screenshots', (tester) async {
    const destination = String.fromEnvironment('QUIZ_ROOT_SCREENSHOT_DIR');
    if (destination.isEmpty) return;
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await loadCaptureFonts(tester);
    final captureKey = GlobalKey();
    final dependencies = _dependencies(_QuizRepository(), _Store());

    Future<void> capture(String name) async {
      await tester.pumpAndSettle();
      final boundary =
          captureKey.currentContext!.findRenderObject()!
              as RenderRepaintBoundary;
      final image = (await tester.runAsync(boundary.toImage))!;
      final bytes = await tester.runAsync(
        () => image.toByteData(format: ui.ImageByteFormat.png),
      );
      await tester.runAsync(() async {
        await Directory(destination).create(recursive: true);
        await File(
          '$destination/$name.png',
        ).writeAsBytes(bytes!.buffer.asUint8List());
      });
      image.dispose();
    }

    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.light,
        home: RepaintBoundary(
          key: captureKey,
          child: AppRootShell(
            onThisDayRepository: _TodayRepository(),
            timezoneProvider: const _Timezone(),
            quizDependencies: () => dependencies,
            onShowDebugNotification: () {},
          ),
        ),
      ),
    );
    await capture('root-today');
    await tester.tap(find.byType(NavigationDestination).at(1));
    expect(find.byType(AppBar), findsOneWidget);
    expect(find.text('On This Day'), findsOneWidget);
    await capture('root-quiz');
    expect(tester.takeException(), isNull);
  });

  testWidgets(
    'Results Done returns to a retained Hub showing the confirmed Daily',
    (tester) async {
      final quizRepository = _QuizRepository();
      final store = _ControlledStore();
      final dependencies = _dependencies(quizRepository, store);
      final navigatorKey = await _pumpRoutedShell(tester, dependencies);
      dependencies.rootStatus.update(_dailyStatus);
      await tester.pumpAndSettle();
      expect(find.text('Get ready for 5 questions'), findsOneWidget);

      final completion = _dailyClaim('official-daily');
      await _finishDailyAndOpenResults(
        tester,
        navigatorKey,
        dependencies,
        completion,
      );
      store.succeed(QuizSavedClassification.official);
      await tester.pumpAndSettle();
      expect(find.text('Official Daily result'), findsOneWidget);
      await _tapResultsDone(tester);

      expect(find.byType(QuizResultsScreen), findsNothing);
      expect(find.text('Sep 13'), findsOneWidget);
      expect(find.text('Today\'s score: 5 / 5'), findsOneWidget);
      expect(find.text('Today\'s official score is saved.'), findsOneWidget);
      expect(find.text('Practice again'), findsOneWidget);
      expect(find.text('Get ready for 5 questions'), findsNothing);
      expect(quizRepository.catalogCalls, 1);

      await tester.tap(find.byType(NavigationDestination).at(0));
      await tester.pumpAndSettle();
      await tester.tap(find.byType(NavigationDestination).at(1));
      await tester.pumpAndSettle();
      expect(find.text('Today\'s score: 5 / 5'), findsOneWidget);
      expect(quizRepository.catalogCalls, 1);

      await tester.tap(find.text('Review answers'));
      await tester.pumpAndSettle();
      final review = tester.widget<QuizFullReviewScreen>(
        find.byType(QuizFullReviewScreen),
      );
      expect(review.result, same(completion.result));
      expect(
        store.completions.single.intent,
        QuizSaveIntent.claimDailyIfAbsent,
      );
    },
  );

  testWidgets('pending or failed Daily saves hide the score', (tester) async {
    final quizRepository = _QuizRepository();
    final store = _ControlledStore();
    final dependencies = _dependencies(quizRepository, store);
    final navigatorKey = await _pumpRoutedShell(tester, dependencies);
    dependencies.rootStatus.update(_dailyStatus);

    await _finishDailyAndOpenResults(
      tester,
      navigatorKey,
      dependencies,
      _dailyClaim('pending-daily'),
    );
    await _tapResultsDone(tester);

    expect(find.text('Saving today\'s result…'), findsOneWidget);
    expect(find.textContaining('Today\'s score'), findsNothing);
    expect(find.text('Review answers'), findsNothing);
    expect(dependencies.rootStatus.value!.blocksOfficialClaim, isTrue);

    store.fail(StateError('disk unavailable'));
    await tester.pumpAndSettle();

    expect(
      find.text(
        'Today\'s result has not been saved yet. '
        'Another attempt will count as practice.',
      ),
      findsOneWidget,
    );
    expect(find.textContaining('Today\'s score'), findsNothing);
    expect(find.text('Review answers'), findsNothing);
    expect(find.text('Set up today\'s challenge'), findsOneWidget);
    expect(quizRepository.catalogCalls, 1);
  });

  testWidgets('representative completed-Daily Hub screenshot', (tester) async {
    const destination = String.fromEnvironment('QUIZ_ROOT_SCREENSHOT_DIR');
    if (destination.isEmpty) return;
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await loadCaptureFonts(tester);
    final captureKey = GlobalKey();
    final store = _ControlledStore();
    final dependencies = _dependencies(_QuizRepository(), store);
    final navigatorKey = await _pumpRoutedShell(
      tester,
      dependencies,
      captureKey: captureKey,
    );
    dependencies.rootStatus.update(_dailyStatus);
    await _finishDailyAndOpenResults(
      tester,
      navigatorKey,
      dependencies,
      _dailyClaim('screenshot-daily'),
    );
    store.succeed(QuizSavedClassification.official);
    await tester.pumpAndSettle();
    await _tapResultsDone(tester);

    final boundary =
        captureKey.currentContext!.findRenderObject()! as RenderRepaintBoundary;
    final image = (await tester.runAsync(boundary.toImage))!;
    final bytes = await tester.runAsync(
      () => image.toByteData(format: ui.ImageByteFormat.png),
    );
    await tester.runAsync(() async {
      await Directory(destination).create(recursive: true);
      await File(
        '$destination/root-quiz-daily-complete.png',
      ).writeAsBytes(bytes!.buffer.asUint8List());
    });
    image.dispose();
    expect(tester.takeException(), isNull);
  });
}

QuizRouteDependencies _dependencies(
  QuizRepository repository,
  QuizResultStore store,
) {
  final coordinator = QuizCompletionCoordinator(store);
  return QuizRouteDependencies(
    repository: repository,
    resultStore: store,
    completionCoordinator: coordinator,
    imagePreparer: QuizImagePreparer(
      downloader: _NoopDownloader(),
      decoder: _NoopDecoder(),
    ),
    timezoneProvider: const _Timezone(),
    completionIdGenerator: const _Ids(),
    sourceLauncher: const PlatformSourceLauncher(),
    rootStatus: QuizRootStatus(coordinator),
  );
}

/// Mounts the real router so Results "Done" pops to the retained root shell.
Future<GlobalKey<NavigatorState>> _pumpRoutedShell(
  WidgetTester tester,
  QuizRouteDependencies dependencies, {
  GlobalKey? captureKey,
}) async {
  final navigatorKey = GlobalKey<NavigatorState>();
  final router = AppRouter(
    repository: _TodayRepository(),
    timezoneProvider: const _Timezone(),
    quizDependencies: () => dependencies,
    navigatorKey: navigatorKey,
  );
  await tester.pumpWidget(
    MaterialApp(
      theme: AppTheme.light,
      navigatorKey: navigatorKey,
      onGenerateRoute: router.onGenerateRoute,
      builder: captureKey == null
          ? null
          : (context, child) => RepaintBoundary(key: captureKey, child: child),
    ),
  );
  await tester.pumpAndSettle();
  await tester.tap(find.byType(NavigationDestination).at(1));
  await tester.pumpAndSettle();
  return navigatorKey;
}

/// Stands in for Daily Setup resolving the backend date before gameplay.
final _dailyStatus = DailyChallengeStatus(
  date: QuizDate('2026-09-13'),
  displayDate: 'Sep 13',
);

Future<void> _finishDailyAndOpenResults(
  WidgetTester tester,
  GlobalKey<NavigatorState> navigatorKey,
  QuizRouteDependencies dependencies,
  QuizCompletion completion,
) async {
  dependencies.completionCoordinator.complete(completion).ignore();
  unawaited(
    navigatorKey.currentState!.pushNamed(
      AppRoutes.results,
      arguments: ResultsRouteArguments(completion.result.completionId),
    ),
  );
  await tester.pumpAndSettle();
}

Future<void> _tapResultsDone(WidgetTester tester) async {
  final done = find.widgetWithText(OutlinedButton, 'Done');
  await tester.ensureVisible(done);
  await tester.tap(done);
  await tester.pumpAndSettle();
}

QuizCompletion _dailyClaim(String id) {
  final definition = sessionQuiz(daily: true) as DailyQuizDefinition;
  return QuizCompletion(
    QuizResult(
      completionId: id,
      definition: definition,
      timingEnabled: true,
      completedAt: DateTime.utc(2026, 9, 13),
      reason: QuizCompletionReason.questionsFinished,
      outcomes: [
        for (final question in definition.questions)
          QuestionOutcome.answered(
            question,
            question is ChoiceQuestion
                ? OptionAnswer(question.correctOptionId)
                : OrderingAnswer(
                    (question as ChronologicalOrderingQuestion)
                        .correctOrderItemIds,
                  ),
          ),
      ],
    ),
    QuizSaveIntent.claimDailyIfAbsent,
  );
}

final class _QuizRepository implements QuizRepository {
  int catalogCalls = 0;
  @override
  Future<QuizCatalog> getCatalog() async {
    catalogCalls++;
    return QuizCatalog(
      mixed: QuizAvailability(
        publishedQuestionCount: 5,
        supportedQuestionCounts: const [5],
      ),
      collections: const [],
      quickPlayTimerDefaults: QuizRules.quickPlayDefaults,
    );
  }

  @override
  Future<DailyQuizDefinition> getDaily({
    required String timezone,
    required int questionCount,
  }) async => sessionQuiz(daily: true) as DailyQuizDefinition;

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
  Future<List<RecentDay>> getRecentDays(String timezone) async => const [];

  @override
  Future<HistoricalEvent> getEvent(String eventId) async => HistoricalEvent(
    id: eventId,
    hasRelatedQuizQuestions: true,
    title: 'Test event',
    year: '1900',
    historicalDate: 'September 14, 1900',
    summary: 'A short test summary.',
    description: 'A short test description.',
    sources: [
      EventSource(name: 'Test source', url: Uri.parse('https://example.com')),
    ],
  );
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

final class _ControlledStore extends _Store {
  final completions = <QuizCompletion>[];
  final _pending = <Completer<StoredQuizResult>>[];

  @override
  Future<StoredQuizResult> saveCompletion(QuizCompletion completion) {
    completions.add(completion);
    final pending = Completer<StoredQuizResult>();
    _pending.add(pending);
    return pending.future;
  }

  void succeed(QuizSavedClassification classification) {
    final index = _pending.indexWhere((item) => !item.isCompleted);
    _pending[index].complete(
      StoredQuizResult(completions[index].result, classification),
    );
  }

  void fail(Object error) =>
      _pending.firstWhere((item) => !item.isCompleted).completeError(error);
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
