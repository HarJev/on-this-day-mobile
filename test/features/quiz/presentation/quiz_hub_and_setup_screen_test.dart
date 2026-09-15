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
import 'package:on_this_day_mobile/features/quiz/domain/quiz_catalog.dart';
import 'package:on_this_day_mobile/features/quiz/domain/quiz_definition.dart';
import 'package:on_this_day_mobile/features/quiz/domain/quiz_repository.dart';
import 'package:on_this_day_mobile/features/quiz/domain/quiz_result.dart';
import 'package:on_this_day_mobile/features/quiz/domain/quiz_result_store.dart';
import 'package:on_this_day_mobile/features/quiz/domain/quiz_rules.dart';
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
    await tester.tap(find.text('Set up Daily Challenge'));
    expect(daily, 1);
    expect(quick, 0);
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
      await tester.tap(find.text('Start Challenge (5 Questions)'));
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
        QuizHubScreen(
          repository: _Repo(),
          onOpenDaily: (_) {},
          onOpenQuickPlay: (_) {},
        ),
      ),
    );
    await capture('hub');
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
  final QuizCatalog _catalog;
  int dailyCalls = 0;

  @override
  Future<QuizCatalog> getCatalog() async => _catalog;

  @override
  Future<DailyQuizDefinition> getDaily({
    required String timezone,
    required int questionCount,
  }) async {
    dailyCalls++;
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

final class _Ids implements QuizCompletionIdGenerator {
  const _Ids();
  @override
  String nextId() => 'setup-launch';
}

final class _Store implements QuizResultStore {
  @override
  Future<StoredQuizResult?> getOfficialDaily(QuizDate date) async => null;
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
