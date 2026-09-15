import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:on_this_day_mobile/core/config/app_theme.dart';
import 'package:on_this_day_mobile/core/config/timezone_provider.dart';
import 'package:on_this_day_mobile/core/navigation/app_root_shell.dart';
import 'package:on_this_day_mobile/core/navigation/quiz_route_dependencies.dart';
import 'package:on_this_day_mobile/core/navigation/source_launcher.dart';
import 'package:on_this_day_mobile/features/on_this_day/domain/daily_content.dart';
import 'package:on_this_day_mobile/features/on_this_day/domain/featured_event.dart';
import 'package:on_this_day_mobile/features/on_this_day/domain/historical_event.dart';
import 'package:on_this_day_mobile/features/on_this_day/domain/on_this_day_repository.dart';
import 'package:on_this_day_mobile/features/quiz/application/quiz_completion_coordinator.dart';
import 'package:on_this_day_mobile/features/quiz/application/quiz_completion_id_generator.dart';
import 'package:on_this_day_mobile/features/quiz/application/quiz_root_status.dart';
import 'package:on_this_day_mobile/features/quiz/domain/quiz_catalog.dart';
import 'package:on_this_day_mobile/features/quiz/domain/quiz_definition.dart';
import 'package:on_this_day_mobile/features/quiz/domain/quiz_repository.dart';
import 'package:on_this_day_mobile/features/quiz/domain/quiz_result.dart';
import 'package:on_this_day_mobile/features/quiz/domain/quiz_result_store.dart';
import 'package:on_this_day_mobile/features/quiz/domain/quiz_rules.dart';
import 'package:on_this_day_mobile/features/quiz/presentation/images/quiz_image_decoder.dart';
import 'package:on_this_day_mobile/features/quiz/presentation/images/quiz_image_downloader.dart';
import 'package:on_this_day_mobile/features/quiz/presentation/images/quiz_image_preparer.dart';

void main() {
  testWidgets('creates and loads Quiz only after first root selection', (
    tester,
  ) async {
    final quizRepository = _QuizRepository();
    final store = _Store();
    var factoryCalls = 0;
    final dependencies = QuizRouteDependencies(
      repository: quizRepository,
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
    expect(find.text('Daily Challenge'), findsOneWidget);
    expect(find.byTooltip('Show test notification'), findsNothing);

    await tester.tap(find.byType(NavigationDestination).at(0));
    await tester.tap(find.byType(NavigationDestination).at(1));
    await tester.pumpAndSettle();
    expect(factoryCalls, 1);
    expect(quizRepository.catalogCalls, 1);
  });

  testWidgets('representative retained-shell screenshots', (tester) async {
    const destination = String.fromEnvironment('QUIZ_ROOT_SCREENSHOT_DIR');
    if (destination.isEmpty) return;
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await _loadCaptureFonts(tester);
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
}

QuizRouteDependencies _dependencies(QuizRepository repository, _Store store) =>
    QuizRouteDependencies(
      repository: repository,
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
  }) => throw UnimplementedError();

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
