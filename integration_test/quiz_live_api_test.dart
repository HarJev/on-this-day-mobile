import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:integration_test/integration_test.dart';
import 'package:on_this_day_mobile/core/api/api_client.dart';
import 'package:on_this_day_mobile/core/config/timezone_provider.dart';
import 'package:on_this_day_mobile/core/navigation/app_router.dart';
import 'package:on_this_day_mobile/core/navigation/quiz_route_dependencies.dart';
import 'package:on_this_day_mobile/core/navigation/source_launcher.dart';
import 'package:on_this_day_mobile/features/on_this_day/data/backend_on_this_day_repository.dart';
import 'package:on_this_day_mobile/features/quiz/application/quiz_completion_coordinator.dart';
import 'package:on_this_day_mobile/features/quiz/application/quiz_completion_id_generator.dart';
import 'package:on_this_day_mobile/features/quiz/application/quiz_root_status.dart';
import 'package:on_this_day_mobile/features/quiz/data/backend_quiz_repository.dart';
import 'package:on_this_day_mobile/features/quiz/data/local/quiz_database.dart';
import 'package:on_this_day_mobile/features/quiz/data/local/sqlite_quiz_result_store.dart';
import 'package:on_this_day_mobile/features/quiz/domain/quiz_definition.dart';
import 'package:on_this_day_mobile/features/quiz/domain/quiz_question.dart';
import 'package:on_this_day_mobile/features/quiz/presentation/images/quiz_image_decoder.dart';
import 'package:on_this_day_mobile/features/quiz/presentation/images/quiz_image_downloader.dart';
import 'package:on_this_day_mobile/features/quiz/presentation/images/quiz_image_preparer.dart';
import 'package:on_this_day_mobile/features/quiz/presentation/images/quiz_image_preparation_exception.dart';
import 'package:on_this_day_mobile/features/quiz/presentation/quiz_full_review_screen.dart';
import 'package:on_this_day_mobile/features/quiz/presentation/quiz_gameplay_view.dart';
import 'package:on_this_day_mobile/features/quiz/presentation/quiz_results_screen.dart';
import 'package:on_this_day_mobile/features/quiz/presentation/quiz_session_state.dart';
import 'package:on_this_day_mobile/main.dart';
import '../test/features/quiz/support/image_fakes.dart';

// Explicitly opt in: this suite requires the local SAM API and imported content.
void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();
  const enabled = bool.fromEnvironment('LIVE_API_TEST');
  const baseUrl = String.fromEnvironment('ON_THIS_DAY_API_BASE_URL');
  const fixtureImages = bool.fromEnvironment('LIVE_API_FIXTURE_IMAGES');

  testWidgets(
    'live Quick Play and Daily complete, save, and review',
    (tester) async {
      final directory = await Directory.systemTemp.createTemp('quiz-live-');
      final database = QuizDatabase(
        databasePath: () async => '${directory.path}/results.db',
      );
      final store = SqliteQuizResultStore(database: database);
      final client = http.Client();
      final api = ApiClient(baseUrl: Uri.parse(baseUrl), httpClient: client);
      final repository = BackendQuizRepository(apiClient: api);
      final navigation = GlobalKey<NavigatorState>();
      final observer = RouteObserver<PageRoute<dynamic>>();
      final QuizImageDownloader downloader = fixtureImages
          ? BytesDownloader(await testImageBytes(width: 400, height: 200))
          : HttpQuizImageDownloader(client);
      final coordinator = QuizCompletionCoordinator(store);
      final dependencies = QuizRouteDependencies(
        repository: repository,
        resultStore: store,
        completionCoordinator: coordinator,
        imagePreparer: QuizImagePreparer(
          downloader: downloader,
          decoder: FlutterQuizImageDecoder(),
        ),
        timezoneProvider: const _Timezone(),
        completionIdGenerator: SecureQuizCompletionIdGenerator(),
        sourceLauncher: const PlatformSourceLauncher(),
        rootStatus: QuizRootStatus(coordinator),
      );
      addTearDown(() async {
        client.close();
        await (await database.open()).close();
        await directory.delete(recursive: true);
      });
      await tester.pumpWidget(
        OnThisDayApp(
          navigatorKey: navigation,
          routeObserver: observer,
          router: AppRouter(
            repository: BackendOnThisDayRepository(apiClient: api),
            timezoneProvider: const _Timezone(),
            navigatorKey: navigation,
            routeObserver: observer,
            quizDependencies: () => dependencies,
          ),
        ),
      );
      await _wait(
        tester,
        () => find.byType(NavigationBar).evaluate().isNotEmpty,
      );
      await tester.tap(find.byType(NavigationDestination).at(1));
      await _wait(
        tester,
        () => find.text('Choose a round').evaluate().isNotEmpty,
      );
      await _tap(tester, find.text('Choose a round'));
      await _wait(tester, () => find.text('20').evaluate().isNotEmpty);
      await _tap(tester, find.text('20'));
      await _tap(tester, find.byType(SwitchListTile));
      await tester.pumpAndSettle();
      await _tap(tester, find.text('Continue with 20 questions'));
      await _wait(tester, () => _play(tester)?.controller.state is QuizReady);
      await _tap(tester, find.text('Start quiz'));
      final types = <Type>{};
      await _complete(tester, types);
      expect(
        types.length,
        4,
        reason: 'Mixed 20 should exercise all four types',
      );
      await _tap(tester, find.text('View results'));
      await _wait(
        tester,
        () => find.byType(QuizResultsScreen).evaluate().isNotEmpty,
      );
      await _wait(
        tester,
        () => find.textContaining('Saving').evaluate().isEmpty,
      );
      await _tap(tester, find.text('Review answers'));
      await _wait(
        tester,
        () => find.byType(QuizFullReviewScreen).evaluate().isNotEmpty,
      );
      expect(tester.takeException(), isNull);

      navigation.currentState!.popUntil((route) => route.isFirst);
      await tester.pumpAndSettle();
      // The Hub offers the Daily count choice directly.
      await _wait(
        tester,
        () => find.text('Continue with 5 questions').evaluate().isNotEmpty,
      );
      await _tap(tester, find.text('Continue with 5 questions'));
      await _wait(tester, () => _play(tester)?.controller.state is QuizReady);
      final definition =
          _play(tester)!.controller.definition as DailyQuizDefinition;
      await _tap(tester, find.text('Start challenge'));
      await _complete(tester, <Type>{});
      await _tap(tester, find.text('View results'));
      await _wait(
        tester,
        () => find.byType(QuizResultsScreen).evaluate().isNotEmpty,
      );
      await _wait(
        tester,
        () => find.textContaining('Saving').evaluate().isEmpty,
      );
      final official = await store.getOfficialDaily(definition.date);
      expect(official, isNotNull);
      expect(official!.result.correct, 5);
      await _tap(tester, find.text('Review answers'));
      await _wait(
        tester,
        () => find.byType(QuizFullReviewScreen).evaluate().isNotEmpty,
      );
      await tester.pumpWidget(const SizedBox.shrink());
      await (await database.open()).close();
      final reopened = QuizDatabase(
        databasePath: () async => '${directory.path}/results.db',
      );
      expect(
        await SqliteQuizResultStore(
          database: reopened,
        ).getOfficialDaily(definition.date),
        isNotNull,
      );
      await (await reopened.open()).close();
      expect(tester.takeException(), isNull);
    },
    skip: !enabled,
    timeout: const Timeout(Duration(minutes: 8)),
  );
}

QuizGameplayView? _play(WidgetTester tester) {
  final finder = find.byType(QuizGameplayView);
  return finder.evaluate().isEmpty
      ? null
      : tester.widget<QuizGameplayView>(finder);
}

Future<void> _wait(WidgetTester tester, bool Function() ready) async {
  final deadline = DateTime.now().add(const Duration(seconds: 90));
  while (!ready() && DateTime.now().isBefore(deadline)) {
    final state = _play(tester)?.controller.state;
    if (state is QuizPreparationFailed) {
      final error = state.cause;
      fail(
        'Live preparation failed: $error '
        '${error is QuizImagePreparationException ? error.cause : ""}',
      );
    }
    await tester.pump(const Duration(milliseconds: 100));
    await Future<void>.delayed(const Duration(milliseconds: 100));
  }
  expect(
    ready(),
    isTrue,
    reason: 'Live app did not reach the expected state. '
        'Visible text: ${tester.widgetList<Text>(find.byType(Text)).map((text) => text.data).join(" | ")}',
  );
  expect(tester.takeException(), isNull);
}

Future<void> _tap(WidgetTester tester, Finder finder) async {
  await tester.ensureVisible(finder.first);
  await tester.tap(finder.first);
  await tester.pump(const Duration(milliseconds: 300));
}

Future<void> _complete(WidgetTester tester, Set<Type> types) async {
  while (_play(tester)!.controller.state is! QuizCompleted) {
    final state = _play(tester)!.controller.state;
    if (state is QuizAnswering) {
      final question = state.question;
      types.add(question.runtimeType);
      if (question is ChoiceQuestion) {
        await _tap(
          tester,
          find.byKey(Key('option-${question.correctOptionId}')),
        );
      } else if (question is ChronologicalOrderingQuestion) {
        // Exercise the same accessible movement buttons available to users.
        for (var position = 0;
            position < question.correctOrderItemIds.length;
            position++) {
          final id = question.correctOrderItemIds[position];
          while ((_play(tester)!.controller.state as QuizAnswering)
                  .orderingDraft
                  .indexOf(id) >
              position) {
            final item = question.items.firstWhere((item) => item.id == id);
            await _tap(tester, find.byTooltip('Move ${item.text} up'));
          }
        }
        await _tap(tester, find.text('Submit order'));
      }
    } else if (state is QuizFeedback) {
      await _tap(tester, find.text('Continue'));
    } else {
      fail('Unexpected live session state: $state');
    }
  }
}

final class _Timezone implements TimezoneProvider {
  const _Timezone();
  @override
  Future<String> currentTimezone() async => 'America/Jamaica';
}
