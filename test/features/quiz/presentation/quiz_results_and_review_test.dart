import 'dart:async';
import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:on_this_day_mobile/core/config/app_theme.dart';
import 'package:on_this_day_mobile/core/navigation/source_launcher.dart';
import 'package:on_this_day_mobile/features/quiz/application/quiz_completion_coordinator.dart';
import 'package:on_this_day_mobile/features/quiz/domain/question_outcome.dart';
import 'package:on_this_day_mobile/features/quiz/domain/quiz_answer.dart';
import 'package:on_this_day_mobile/features/quiz/domain/quiz_definition.dart';
import 'package:on_this_day_mobile/features/quiz/domain/quiz_rules.dart';
import 'package:on_this_day_mobile/features/quiz/domain/quiz_result.dart';
import 'package:on_this_day_mobile/features/quiz/domain/quiz_result_store.dart';
import 'package:on_this_day_mobile/features/quiz/presentation/quiz_full_review_screen.dart';
import 'package:on_this_day_mobile/features/quiz/presentation/quiz_results_screen.dart';
import 'package:on_this_day_mobile/features/quiz/presentation/quiz_session_controller.dart';
import 'package:on_this_day_mobile/features/quiz/presentation/widgets/quiz_review_external_link.dart';

import '../support/quiz_completion_flow_host.dart';
import '../support/session_fakes.dart';
import '../../../support/capture_fonts.dart';

void main() {
  testWidgets(
    'Results stays truthful while a Daily claim is pending and saved',
    (tester) async {
      final store = _ControlledStore();
      final coordinator = QuizCompletionCoordinator(store);
      final completion = _dailyCompletion();
      unawaited(_ignoreFailure(coordinator.complete(completion)));

      await tester.pumpWidget(
        _app(
          QuizResultsScreen(
            coordinator: coordinator,
            completionId: completion.result.completionId,
            onReview: (_) {},
            onDone: () {},
          ),
        ),
      );

      expect(find.text('Saving result…'), findsOneWidget);
      expect(find.textContaining('Official Daily result'), findsNothing);
      expect(
        find.bySemanticsLabel('1 correct out of 5, 20 percent'),
        findsOneWidget,
      );
      expect(find.text('Answered'), findsOneWidget);
      expect(find.text('2'), findsOneWidget);
      expect(find.text('3'), findsOneWidget);
      expect(find.text('Unanswered'), findsOneWidget);

      store.succeed(QuizSavedClassification.official);
      await tester.pump();

      expect(find.text('Official Daily result'), findsOneWidget);
      expect(find.text('Saving result…'), findsNothing);
    },
  );

  testWidgets(
    'failed save retries the same frozen result without unhandled UI errors',
    (tester) async {
      final store = _ControlledStore();
      final coordinator = QuizCompletionCoordinator(store);
      final completion = _dailyCompletion();
      unawaited(_ignoreFailure(coordinator.complete(completion)));
      await tester.pumpWidget(
        _app(
          QuizResultsScreen(
            coordinator: coordinator,
            completionId: completion.result.completionId,
            onReview: (_) {},
            onDone: () {},
          ),
        ),
      );

      store.fail(StateError('offline'));
      await tester.pump();
      expect(find.text('Result not saved'), findsOneWidget);
      expect(find.text('Retry'), findsOneWidget);

      await tester.tap(find.text('Retry'));
      await tester.pump();
      expect(find.text('Saving result…'), findsOneWidget);
      expect(store.completions.last.result, same(completion.result));
      store.succeed(QuizSavedClassification.practice);
      await tester.pump();

      expect(
        find.text(
          'Practice result. Today\'s official score was already recorded.',
        ),
        findsOneWidget,
      );
    },
  );

  testWidgets(
    'Review renders every frozen outcome, source and image provenance',
    (tester) async {
      final launcher = _Launcher(result: false);
      final result = _dailyCompletion().result;
      await tester.pumpWidget(
        _app(
          QuizFullReviewScreen(
            result: result,
            sourceLauncher: launcher,
            onDone: () {},
          ),
        ),
      );

      expect(find.text('Correct'), findsOneWidget);
      expect(find.text('Incorrect'), findsOneWidget);

      await tester.scrollUntilVisible(find.text('Skipped'), 200);
      expect(find.text('Skipped'), findsOneWidget);
      expect(find.text('Image unavailable in review.'), findsOneWidget);
      expect(find.textContaining('Alt text:'), findsNothing);
      // Sources and image credit start collapsed and expand in place.
      final imageCredit = find.text('Image credit');
      await tester.ensureVisible(imageCredit);
      await tester.pumpAndSettle();
      await tester.tap(imageCredit);
      await tester.pumpAndSettle();
      final imageCard = find.ancestor(
        of: imageCredit,
        matching: find.byWidgetPredicate(
          (widget) =>
              widget.key is ValueKey<String> &&
              (widget.key as ValueKey<String>).value.startsWith('review-'),
        ),
      );
      final sources = find.descendant(
        of: imageCard,
        matching: find.text('Sources (1)'),
      );
      await tester.ensureVisible(sources);
      await tester.tap(sources);
      await tester.pumpAndSettle();
      expect(find.text('Test museum'), findsWidgets);
      await tester.scrollUntilVisible(find.text('Timed out'), 200);
      expect(find.text('Timed out'), findsOneWidget);
      expect(find.text('Not reached'), findsNothing);
      expect(find.text('Your submitted order'), findsNothing);
      expect(find.text('Correct order'), findsOneWidget);

      await tester.scrollUntilVisible(find.text('Not reached'), 200);
      expect(find.text('Not reached'), findsOneWidget);

      // Full provenance and licence remain available in Review.
      await tester.scrollUntilVisible(find.text('Attribution: Museum'), -200);
      expect(find.text('Attribution: Museum'), findsOneWidget);
      expect(find.text('License: CC0'), findsOneWidget);
      final imageLicense = find.byWidgetPredicate(
        (widget) =>
            widget is QuizReviewExternalLink &&
            (widget.key as ValueKey<String>?)?.value.endsWith(
                  ':image-license',
                ) ==
                true,
      );
      expect(imageLicense, findsOneWidget);
      final licenseButton = find.descendant(
        of: imageLicense,
        matching: find.byType(TextButton),
      );
      await tester.scrollUntilVisible(licenseButton, -200);
      await tester.pumpAndSettle();
      await tester.tap(licenseButton);
      await tester.pump();
      expect(launcher.urls, contains(Uri.parse('https://example.org/license')));
    },
  );

  testWidgets('a missing live coordinator entry is a recoverable view state', (
    tester,
  ) async {
    await tester.pumpWidget(
      _app(
        QuizResultsScreen(
          coordinator: QuizCompletionCoordinator(_ControlledStore()),
          completionId: 'missing',
          onReview: (_) {},
          onDone: () {},
        ),
      ),
    );

    expect(find.text('This completed result is unavailable.'), findsOneWidget);
  });

  testWidgets('a failed review source stays local and can be retried', (
    tester,
  ) async {
    final launcher = _Launcher(result: false);
    await tester.pumpWidget(
      _app(
        Scaffold(
          body: QuizReviewExternalLink(
            label: 'Open source: Test museum',
            url: Uri.parse('https://example.org/source'),
            launcher: launcher,
          ),
        ),
      ),
    );

    await tester.tap(find.text('Open source: Test museum'));
    await tester.pump();
    expect(find.text('Could not open link. Tap to retry.'), findsOneWidget);
    expect(launcher.urls, [Uri.parse('https://example.org/source')]);

    await tester.tap(find.text('Open source: Test museum'));
    await tester.pump();
    expect(launcher.urls, hasLength(2));
  });

  testWidgets(
    'a disposed gameplay route leaves its registered completion available to Results and Review',
    (tester) async {
      final store = _ControlledStore();
      final coordinator = QuizCompletionCoordinator(store);
      final clock = FakeSessionClock();
      final scheduler = FakeSessionScheduler();
      final preparation = FakePreparation();
      late QuizSessionController controller;
      final definition = DailyQuizDefinition(
        questionCount: 5,
        questions: [
          for (var index = 0; index < 5; index++)
            sessionQuestion(index, QuizQuestionType.multipleChoice),
        ],
        challengeId: 'daily-flow',
        date: QuizDate('2026-09-13'),
        displayDate: 'Sep 13',
        duration: const Duration(seconds: 120),
      );

      await tester.pumpWidget(
        _app(
          QuizCompletionFlowHost(
            coordinator: coordinator,
            intent: QuizSaveIntent.claimDailyIfAbsent,
            launcher: _Launcher(result: true),
            createController: (sink) {
              controller = QuizSessionController(
                definition: definition,
                completionId: 'flow-completion',
                timingEnabled: true,
                clock: clock,
                scheduler: scheduler,
                prepareSession: preparation.call,
                completionSink: sink,
              );
              return controller;
            },
          ),
        ),
      );

      final prepared = controller.prepare();
      preparation.succeed();
      await prepared;
      controller.start();
      await tester.pump();
      for (var index = 0; index < 5; index++) {
        await tester.tap(find.text('Option a'));
        await tester.pump();
        if (index < 4) {
          await tester.tap(find.text('Continue'));
          await tester.pump();
        }
      }

      await tester.tap(find.text('View results'));
      await tester.pump();
      expect(find.text('Saving result…'), findsOneWidget);
      expect(store.completions, hasLength(1));

      store.succeed(QuizSavedClassification.official);
      await tester.pump();
      expect(find.text('Official Daily result'), findsOneWidget);

      await tester.tap(find.text('Review answers'));
      await tester.pump();
      expect(find.text('Full review'), findsOneWidget);
      expect(store.completions, hasLength(1));
      expect(tester.takeException(), isNull);
    },
  );

  for (final (scale, stacked) in [(1.0, false), (2.0, true)]) {
    testWidgets('Results stats keep whole-word labels at ${scale}x text', (
      tester,
    ) async {
      tester.view.physicalSize = const Size(402, 874);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      // Real bundled faces: the default test font is far wider than the app's.
      await loadCaptureFonts(tester);
      final coordinator = QuizCompletionCoordinator(_ControlledStore());
      final completion = _dailyCompletion();
      unawaited(_ignoreFailure(coordinator.complete(completion)));

      await tester.pumpWidget(
        _captureApp(
          GlobalKey(),
          QuizResultsScreen(
            coordinator: coordinator,
            completionId: completion.result.completionId,
            onReview: (_) {},
            onDone: () {},
          ),
          textScale: scale,
        ),
      );

      final labels = ['Answered', 'Correct', 'Unanswered'];
      for (final label in labels) {
        final paragraph = tester.renderObject<RenderParagraph>(
          find.text(label),
        );
        expect(
          paragraph.getMaxIntrinsicWidth(double.infinity),
          lessThanOrEqualTo(paragraph.size.width + 0.5),
          reason: '$label wraps at ${scale}x',
        );
      }
      final answered = tester.getTopLeft(find.text('Answered'));
      final unanswered = tester.getTopLeft(find.text('Unanswered'));
      expect(unanswered.dy > answered.dy, stacked);
      expect(tester.takeException(), isNull);
    });
  }

  testWidgets('representative Results and Review screenshots', (tester) async {
    const destination = String.fromEnvironment('QUIZ_RESULTS_SCREENSHOT_DIR');
    if (destination.isEmpty) return;
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await loadCaptureFonts(tester);
    final captureKey = GlobalKey();
    final store = _ControlledStore();
    final coordinator = QuizCompletionCoordinator(store);
    final completion = _dailyCompletion();
    unawaited(_ignoreFailure(coordinator.complete(completion)));

    Future<void> capture(String name) async {
      await tester.pumpAndSettle();
      final boundary =
          captureKey.currentContext!.findRenderObject()!
              as RenderRepaintBoundary;
      final image = (await tester.runAsync(() => boundary.toImage()))!;
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
        QuizResultsScreen(
          coordinator: coordinator,
          completionId: completion.result.completionId,
          onReview: (_) {},
          onDone: () {},
        ),
      ),
    );
    await capture('results-pending');

    store.succeed(QuizSavedClassification.official);
    await tester.pump();
    await capture('results-saved');

    await tester.pumpWidget(
      _captureApp(
        captureKey,
        QuizFullReviewScreen(
          result: completion.result,
          sourceLauncher: _Launcher(result: true),
          onDone: () {},
        ),
        textScale: 2,
      ),
    );
    await tester.scrollUntilVisible(find.text('Skipped'), 200);
    await capture('review-large-text');
    expect(tester.takeException(), isNull);
  });
}

Widget _app(Widget home) => MaterialApp(theme: AppTheme.light, home: home);

Widget _captureApp(GlobalKey captureKey, Widget home, {double textScale = 1}) =>
    MaterialApp(
      theme: AppTheme.light,
      builder: (context, child) => MediaQuery(
        data: MediaQuery.of(
          context,
        ).copyWith(textScaler: TextScaler.linear(textScale)),
        child: RepaintBoundary(key: captureKey, child: child!),
      ),
      home: home,
    );

Future<void> _ignoreFailure(Future<Object?> operation) async {
  try {
    await operation;
  } catch (_) {
    // The Results action handles the retryable failure in the test UI.
  }
}

QuizCompletion _dailyCompletion() {
  final definition = sessionQuiz(daily: true) as DailyQuizDefinition;
  return QuizCompletion(
    QuizResult(
      completionId: 'result-one',
      definition: definition,
      timingEnabled: true,
      completedAt: DateTime.utc(2026, 9, 13),
      reason: QuizCompletionReason.dailyTimeExpired,
      outcomes: [
        QuestionOutcome.answered(definition.questions[0], OptionAnswer('a')),
        QuestionOutcome.answered(
          definition.questions[1],
          OptionAnswer('false'),
        ),
        QuestionOutcome.unanswered(
          definition.questions[2],
          UnansweredReason.imageSkipped,
        ),
        QuestionOutcome.timedOut(definition.questions[3]),
        QuestionOutcome.unanswered(
          definition.questions[4],
          UnansweredReason.notReached,
        ),
      ],
    ),
    QuizSaveIntent.claimDailyIfAbsent,
  );
}

final class _ControlledStore implements QuizResultStore {
  final completions = <QuizCompletion>[];
  final pending = <Completer<StoredQuizResult>>[];

  @override
  Future<StoredQuizResult> saveCompletion(QuizCompletion completion) {
    completions.add(completion);
    final value = Completer<StoredQuizResult>();
    pending.add(value);
    return value.future;
  }

  void succeed(QuizSavedClassification classification) {
    final index = pending.indexWhere((item) => !item.isCompleted);
    pending[index].complete(
      StoredQuizResult(completions[index].result, classification),
    );
  }

  void fail(Object error) =>
      pending.firstWhere((item) => !item.isCompleted).completeError(error);

  @override
  Future<StoredQuizResult?> getBestResult(QuizBestResultKey key) async => null;
  @override
  Future<StoredQuizResult?> getOfficialDaily(QuizDate date) async => null;
  @override
  Future<bool> getQuickPlayTimingEnabled() async => true;
  @override
  Future<void> setQuickPlayTimingEnabled(bool enabled) async {}
}

final class _Launcher implements SourceLauncher {
  _Launcher({required this.result});
  final bool result;
  final urls = <Uri>[];
  @override
  Future<bool> open(Uri url) async {
    urls.add(url);
    return result;
  }
}
