import 'dart:async';
import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:on_this_day_mobile/core/config/app_theme.dart';
import 'package:on_this_day_mobile/core/config/timezone_provider.dart';
import 'package:on_this_day_mobile/features/quiz/application/daily_challenge_status.dart';
import 'package:on_this_day_mobile/features/quiz/application/quiz_completion_coordinator.dart';
import 'package:on_this_day_mobile/features/quiz/application/quiz_completion_id_generator.dart';
import 'package:on_this_day_mobile/features/quiz/application/quiz_session_launch_request.dart';
import 'package:on_this_day_mobile/features/quiz/domain/question_outcome.dart';
import 'package:on_this_day_mobile/features/quiz/domain/quiz_answer.dart';
import 'package:on_this_day_mobile/features/quiz/domain/quiz_catalog.dart';
import 'package:on_this_day_mobile/features/quiz/domain/quiz_definition.dart';
import 'package:on_this_day_mobile/features/quiz/domain/quiz_exceptions.dart';
import 'package:on_this_day_mobile/features/quiz/domain/quiz_repository.dart';
import 'package:on_this_day_mobile/features/quiz/domain/quiz_result.dart';
import 'package:on_this_day_mobile/features/quiz/domain/quiz_result_store.dart';
import 'package:on_this_day_mobile/features/quiz/domain/quiz_rules.dart';
import 'package:on_this_day_mobile/features/quiz/presentation/daily_challenge_setup_controller.dart';
import 'package:on_this_day_mobile/features/quiz/presentation/daily_challenge_setup_screen.dart';
import 'package:on_this_day_mobile/features/quiz/presentation/quick_play_setup_screen.dart';
import 'package:on_this_day_mobile/features/quiz/presentation/quiz_hub_screen.dart';

import '../support/session_fakes.dart';

void main() {
  testWidgets('Hub is a compact root surface without bottom navigation', (
    tester,
  ) async {
    var daily = 0;
    var quick = 0;
    await tester.pumpWidget(
      _app(
        QuizHubScreen(
          repository: _Repo(),
          onOpenDaily: (_) => daily++,
          onOpenQuickPlay: (_) => quick++,
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Daily Challenge'), findsOneWidget);
    expect(find.text('Quick Play'), findsOneWidget);
    expect(find.byTooltip('Back'), findsNothing);
    expect(find.byType(BottomNavigationBar), findsNothing);
    await tester.tap(find.text('Choose challenge'));
    expect(daily, 1);
    expect(quick, 0);
  });

  group('Hub Daily launch', () {
    testWidgets('offers supported counts and launches the selected count', (
      tester,
    ) async {
      _tallView(tester);
      final repository = _Repo(catalog: _catalog(mixedCount: 20));
      final launches = <QuizSessionLaunchRequest>[];
      final statuses = <DailyChallengeStatus>[];
      var setupOpened = 0;
      await tester.pumpWidget(
        _app(
          _inlineHub(
            repository,
            onLaunch: launches.add,
            onStatus: statuses.add,
            onOpenDaily: (_) => setupOpened++,
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(repository.dailyCounts, [5]);
      expect(statuses.single.displayDate, 'Sep 14');
      expect(find.text('Sep 14'), findsOneWidget);
      expect(find.text('Choose challenge'), findsNothing);
      expect(find.textContaining('first completed result'), findsOneWidget);
      expect(find.text('2 min'), findsOneWidget);
      expect(find.text('4 min'), findsOneWidget);
      expect(find.text('8 min'), findsOneWidget);
      expect(find.text('Continue with 5 questions'), findsOneWidget);

      await tester.tap(find.text('10'));
      await tester.pump();
      expect(repository.dailyCounts, [5]);
      await tester.tap(find.text('Continue with 10 questions'));
      await tester.pumpAndSettle();

      expect(repository.dailyCounts, [5, 10]);
      expect(launches, hasLength(1));
      expect(launches.single.definition, isA<DailyQuizDefinition>());
      expect(launches.single.saveIntent, QuizSaveIntent.claimDailyIfAbsent);
      expect(launches.single.timingEnabled, isTrue);
      expect(setupOpened, 0);
      expect(repository.catalogCalls, 1);
    });

    testWidgets('start is single-flight and a disposed Hub never launches', (
      tester,
    ) async {
      _tallView(tester);
      final repository = _Repo();
      final launches = <QuizSessionLaunchRequest>[];
      await tester.pumpWidget(
        _app(_inlineHub(repository, onLaunch: launches.add)),
      );
      await tester.pumpAndSettle();

      final gate = Completer<void>();
      repository.hold = gate;
      await tester.tap(find.text('Continue with 5 questions'));
      await tester.pump();
      expect(find.text('Getting your challenge ready…'), findsOneWidget);
      expect(
        tester
            .widget<ButtonStyleButton>(
              find.ancestor(
                of: find.text('Getting your challenge ready…'),
                matching: find.bySubtype<ButtonStyleButton>(),
              ),
            )
            .onPressed,
        isNull,
      );
      await tester.tap(find.text('Getting your challenge ready…'));
      await tester.pump();
      expect(repository.dailyCounts, [5, 5]);

      await tester.pumpWidget(const SizedBox.shrink());
      gate.complete();
      await tester.pumpAndSettle();
      expect(launches, isEmpty);
      expect(tester.takeException(), isNull);
    });

    testWidgets('invalid timezone stays on the card and Retry recovers', (
      tester,
    ) async {
      _tallView(tester);
      final timezone = _MutableTimezone('  ');
      var quick = 0;
      await tester.pumpWidget(
        _app(
          _inlineHub(
            _Repo(),
            timezone: timezone,
            onOpenQuickPlay: (_) => quick++,
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Could not determine your timezone.'), findsOneWidget);
      expect(find.text('Question count'), findsNothing);
      await tester.tap(find.text('Choose a round'));
      expect(quick, 1);

      timezone.value = 'America/Jamaica';
      await tester.tap(find.text('Retry'));
      await tester.pumpAndSettle();
      expect(find.text('Could not determine your timezone.'), findsNothing);
      expect(find.text('Continue with 5 questions'), findsOneWidget);
    });

    testWidgets('a failed start keeps the Hub recoverable without launching', (
      tester,
    ) async {
      _tallView(tester);
      final repository = _Repo();
      final launches = <QuizSessionLaunchRequest>[];
      await tester.pumpWidget(
        _app(_inlineHub(repository, onLaunch: launches.add)),
      );
      await tester.pumpAndSettle();

      repository.error = const QuizException(
        QuizFailureKind.request,
        'Check your connection and try again.',
      );
      await tester.tap(find.text('Continue with 5 questions'));
      await tester.pumpAndSettle();
      expect(launches, isEmpty);
      expect(find.text('Check your connection and try again.'), findsOneWidget);
      expect(
        find.textContaining('The challenge is for Sep 14'),
        findsOneWidget,
      );

      await tester.tap(find.text('Retry'));
      await tester.pumpAndSettle();
      expect(find.text('Continue with 5 questions'), findsOneWidget);
      expect(launches, isEmpty);
    });

    testWidgets('an unavailable Daily shows no count choice and can retry', (
      tester,
    ) async {
      _tallView(tester);
      final repository = _Repo(
        catalog: _catalog(
          mixedCount: 0,
          collections: [_collection('wars', _availability(5))],
        ),
      );
      await tester.pumpWidget(_app(_inlineHub(repository)));
      await tester.pumpAndSettle();

      expect(
        find.text('Daily Challenge is not available right now.'),
        findsOneWidget,
      );
      expect(find.text('Question count'), findsNothing);
      expect(find.text('Choose challenge'), findsNothing);
      expect(find.text('Choose a round'), findsOneWidget);
      expect(repository.dailyCounts, isEmpty);

      repository.catalog = _catalog(mixedCount: 5);
      await tester.tap(find.text('Retry'));
      await tester.pumpAndSettle();
      expect(repository.catalogCalls, 2);
      expect(repository.dailyCounts, [5]);
      expect(
        find.text('Daily Challenge is not available right now.'),
        findsNothing,
      );
      expect(find.text('Continue with 5 questions'), findsOneWidget);
    });

    testWidgets('a completed Daily keeps its score and Practice again', (
      tester,
    ) async {
      _tallView(tester);
      var setupOpened = 0;
      await tester.pumpWidget(
        _app(
          _inlineHub(
            _Repo(),
            dailyStatus: _completedStatus(),
            onOpenDaily: (_) => setupOpened++,
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.textContaining('Today\'s score:'), findsOneWidget);
      expect(find.text('Review answers'), findsOneWidget);
      expect(find.text('Question count'), findsNothing);
      expect(find.textContaining('Continue with'), findsNothing);
      await tester.tap(find.text('Practice again'));
      expect(setupOpened, 1);
    });

    testWidgets('a stored official result found by the Hub hides the count', (
      tester,
    ) async {
      _tallView(tester);
      final statuses = <DailyChallengeStatus>[];
      await tester.pumpWidget(
        _app(
          _inlineHub(
            _Repo(),
            store: _Store(official: _storedOfficial()),
            onStatus: statuses.add,
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(statuses.single.hasConfirmedOfficial, isTrue);
      expect(find.textContaining('Today\'s score:'), findsOneWidget);
      expect(find.text('Practice again'), findsOneWidget);
      expect(find.text('Question count'), findsNothing);
    });

    testWidgets(
      'a result saved before start shows status instead of launching',
      (tester) async {
        _tallView(tester);
        final store = _Store();
        final launches = <QuizSessionLaunchRequest>[];
        await tester.pumpWidget(
          _app(_inlineHub(_Repo(), store: store, onLaunch: launches.add)),
        );
        await tester.pumpAndSettle();

        store.official = _storedOfficial();
        await tester.tap(find.text('Continue with 5 questions'));
        await tester.pumpAndSettle();

        expect(launches, isEmpty);
        expect(find.textContaining('Today\'s score:'), findsOneWidget);
        expect(find.text('Question count'), findsNothing);
      },
    );
  });

  testWidgets(
    'Daily setup fetches one preview and hands off a selected launch',
    (tester) async {
      final repository = _Repo();
      QuizSessionLaunchRequest? launch;
      DailyChallengeStatus? status;
      await tester.pumpWidget(
        _app(
          DailyChallengeSetupScreen(
            repository: repository,
            timezoneProvider: const _Timezone(),
            resultStore: _Store(),
            completionCoordinator: QuizCompletionCoordinator(_Store()),
            completionIdGenerator: const _Ids(),
            availability: _availability(5),
            onLaunch: (value) => launch = value,
            onStatusResolved: (value) => status = value,
            onBack: () {},
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(repository.dailyCalls, 1);
      expect(status!.displayDate, 'Sep 14');
      expect(find.text('Sep 14'), findsOneWidget);
      expect(find.text('2 min'), findsOneWidget);
      expect(find.textContaining('first completed result'), findsOneWidget);
      await tester.tap(find.text('Continue with 5 questions'));
      await tester.pumpAndSettle();

      expect(repository.dailyCalls, 2);
      expect(launch!.definition, isA<DailyQuizDefinition>());
      expect(launch!.completionId, 'setup-launch');
      expect(launch!.timingEnabled, isTrue);
    },
  );

  testWidgets('Quick setup groups collections and disables an invalid count', (
    tester,
  ) async {
    final catalog = _catalog(
      mixedCount: 10,
      collections: [_collection('wars', _availability(5))],
    );
    await tester.pumpWidget(
      _app(
        QuickPlaySetupScreen(
          repository: _Repo(catalog: catalog),
          resultStore: _Store(),
          completionIdGenerator: const _Ids(),
          catalog: catalog,
          onLaunch: (_) {},
          onBack: () {},
        ),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.text('10').first);
    await tester.pump();
    await tester.tap(find.text('Mixed'));
    await tester.pumpAndSettle();
    expect(find.text('Topic'), findsOneWidget);
    await tester.tap(find.text('Collection wars'));
    await tester.pumpAndSettle();

    expect(
      find.text('Choose a supported question count for this collection.'),
      findsOneWidget,
    );
    expect(
      tester.widget<FilledButton>(find.byType(FilledButton)).onPressed,
      isNull,
    );

    await tester.tap(find.text('Collection wars'));
    await tester.pumpAndSettle();
    Navigator.of(tester.element(find.text('Choose collection'))).pop();
    await tester.pumpAndSettle();
    expect(find.text('Collection wars'), findsOneWidget);

    await tester.tap(find.text('Collection wars'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Mixed'));
    await tester.pumpAndSettle();
    expect(find.text('Mixed'), findsOneWidget);
    expect(
      tester.widget<FilledButton>(find.byType(FilledButton)).onPressed,
      isNotNull,
    );
  });

  testWidgets('representative Hub and setup screenshots', (tester) async {
    const destination = String.fromEnvironment('QUIZ_SETUP_SCREENSHOT_DIR');
    if (destination.isEmpty) return;
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await _loadCaptureFonts(tester);
    final captureKey = GlobalKey();

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
      _captureApp(
        captureKey,
        _inlineHub(_Repo(catalog: _catalog(mixedCount: 20))),
      ),
    );
    await capture('hub');
    await tester.pumpWidget(
      _captureApp(
        captureKey,
        _inlineHub(
          _Repo(),
          store: _Store(official: _storedOfficial()),
          dailyStatus: _completedStatus(),
        ),
      ),
    );
    await capture('hub-daily-completed');
    await tester.pumpWidget(
      _captureApp(
        captureKey,
        DailyChallengeSetupScreen(
          repository: _Repo(),
          timezoneProvider: const _Timezone(),
          resultStore: _Store(),
          completionCoordinator: QuizCompletionCoordinator(_Store()),
          completionIdGenerator: const _Ids(),
          availability: _availability(5),
          onLaunch: (_) {},
          onStatusResolved: (_) {},
          onBack: () {},
        ),
        textScale: 2,
      ),
    );
    await capture('daily-setup-large-text');
    expect(tester.takeException(), isNull);
  });
}

QuizHubScreen _inlineHub(
  _Repo repository, {
  TimezoneProvider timezone = const _Timezone(),
  _Store? store,
  DailyChallengeStatus? dailyStatus,
  ValueChanged<QuizSessionLaunchRequest>? onLaunch,
  ValueChanged<DailyChallengeStatus>? onStatus,
  ValueChanged<QuizCatalog>? onOpenDaily,
  ValueChanged<QuizCatalog>? onOpenQuickPlay,
}) {
  final resultStore = store ?? _Store();
  return QuizHubScreen(
    repository: repository,
    dailyStatus: dailyStatus,
    onOpenDaily: onOpenDaily ?? (_) {},
    onOpenQuickPlay: onOpenQuickPlay ?? (_) {},
    onReviewDailyResult: (_) {},
    createDailySetup: (availability) => DailyChallengeSetupController(
      repository: repository,
      timezoneProvider: timezone,
      resultStore: resultStore,
      completionCoordinator: QuizCompletionCoordinator(resultStore),
      completionIdGenerator: const _Ids(),
      availability: availability,
    ),
    onLaunchDaily: onLaunch ?? (_) {},
    onDailyStatusResolved: onStatus ?? (_) {},
  );
}

void _tallView(WidgetTester tester) {
  tester.view.physicalSize = const Size(800, 1600);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
}

StoredQuizResult _storedOfficial() {
  final definition = DailyQuizDefinition(
    questionCount: 5,
    questions: [
      for (var index = 0; index < 5; index++)
        sessionQuestion(index, QuizQuestionType.multipleChoice),
    ],
    challengeId: 'daily-2026-09-14',
    date: QuizDate('2026-09-14'),
    displayDate: 'Sep 14',
    duration: const Duration(minutes: 2),
  );
  return StoredQuizResult(
    QuizResult(
      completionId: 'official',
      definition: definition,
      timingEnabled: true,
      completedAt: DateTime.utc(2026, 9, 14),
      reason: QuizCompletionReason.questionsFinished,
      outcomes: [
        for (final question in definition.questions)
          QuestionOutcome.answered(question, OptionAnswer('a')),
      ],
    ),
    QuizSavedClassification.official,
  );
}

DailyChallengeStatus _completedStatus() => DailyChallengeStatus(
  date: QuizDate('2026-09-14'),
  displayDate: 'Sep 14',
  confirmedOfficialResult: _storedOfficial(),
);

Widget _app(Widget home) => MaterialApp(theme: AppTheme.light, home: home);

Widget _captureApp(GlobalKey key, Widget home, {double textScale = 1}) =>
    MaterialApp(
      theme: AppTheme.light,
      builder: (context, child) => MediaQuery(
        data: MediaQuery.of(
          context,
        ).copyWith(textScaler: TextScaler.linear(textScale)),
        child: RepaintBoundary(key: key, child: child!),
      ),
      home: home,
    );

Future<void> _loadCaptureFonts(WidgetTester tester) async {
  for (final entry in {
    'Roboto': '/System/Library/Fonts/Supplemental/Arial.ttf',
    'Georgia': '/System/Library/Fonts/Supplemental/Georgia.ttf',
    'MaterialIcons':
        '${Platform.environment['FLUTTER_ROOT']}/bin/cache/artifacts/material_fonts/MaterialIcons-Regular.otf',
  }.entries) {
    final bytes = await tester.runAsync(() => File(entry.value).readAsBytes());
    final loader = FontLoader(entry.key)
      ..addFont(Future.value(ByteData.sublistView(bytes!)));
    await loader.load();
  }
}

QuizCatalog _catalog({
  int mixedCount = 5,
  List<QuizCollection> collections = const [],
}) => QuizCatalog(
  mixed: _availability(mixedCount),
  collections: collections,
  quickPlayTimerDefaults: QuizRules.quickPlayDefaults,
);

QuizAvailability _availability(int count) => QuizAvailability(
  publishedQuestionCount: count,
  supportedQuestionCounts: [
    for (final supported in QuizRules.questionCounts)
      if (supported <= count) supported,
  ],
);

QuizCollection _collection(String id, QuizAvailability availability) =>
    QuizCollection(
      id: id,
      name: 'Collection $id',
      group: QuizCollectionGroup.topic,
      availability: availability,
    );

DailyQuizDefinition _daily() => DailyQuizDefinition(
  questionCount: 5,
  questions: sessionQuestions(),
  challengeId: 'daily-2026-09-14',
  date: QuizDate('2026-09-14'),
  displayDate: 'Sep 14',
  duration: const Duration(minutes: 99),
);

final class _Repo implements QuizRepository {
  _Repo({QuizCatalog? catalog}) : _catalog = catalog ?? _defaultCatalog();
  QuizCatalog _catalog;
  set catalog(QuizCatalog value) => _catalog = value;
  int catalogCalls = 0;
  int dailyCalls = 0;
  final dailyCounts = <int>[];
  Completer<void>? hold;
  Object? error;

  @override
  Future<QuizCatalog> getCatalog() async {
    catalogCalls++;
    return _catalog;
  }

  @override
  Future<DailyQuizDefinition> getDaily({
    required String timezone,
    required int questionCount,
  }) async {
    dailyCalls++;
    dailyCounts.add(questionCount);
    final gate = hold;
    hold = null;
    if (gate != null) await gate.future;
    final failure = error;
    error = null;
    if (failure != null) throw failure;
    return _daily();
  }

  @override
  Future<QuickPlayQuizDefinition> createQuickPlay({
    required int questionCount,
    String? collectionId,
  }) => throw UnimplementedError();
}

final class _Timezone implements TimezoneProvider {
  const _Timezone();
  @override
  Future<String> currentTimezone() async => 'America/Jamaica';
}

final class _MutableTimezone implements TimezoneProvider {
  _MutableTimezone(this.value);
  String value;
  @override
  Future<String> currentTimezone() async => value;
}

final class _Ids implements QuizCompletionIdGenerator {
  const _Ids();
  @override
  String nextId() => 'setup-launch';
}

final class _Store implements QuizResultStore {
  _Store({this.official});
  StoredQuizResult? official;

  @override
  Future<StoredQuizResult?> getOfficialDaily(QuizDate date) async => official;
  @override
  Future<StoredQuizResult?> getBestResult(QuizBestResultKey key) async => null;
  @override
  Future<bool> getQuickPlayTimingEnabled() async => true;
  @override
  Future<void> setQuickPlayTimingEnabled(bool enabled) async {}
  @override
  Future<StoredQuizResult> saveCompletion(QuizCompletion completion) async =>
      StoredQuizResult(completion.result, QuizSavedClassification.official);
}

QuizCatalog _defaultCatalog() => _catalog();
