import 'dart:async';
import 'dart:io';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:on_this_day_mobile/core/config/app_theme.dart';
import 'package:on_this_day_mobile/core/navigation/source_launcher.dart';
import 'package:on_this_day_mobile/features/quiz/domain/quiz_definition.dart';
import 'package:on_this_day_mobile/features/quiz/domain/quiz_rules.dart';
import 'package:on_this_day_mobile/features/quiz/domain/quiz_result.dart';
import 'package:on_this_day_mobile/features/quiz/presentation/quiz_session_controller.dart';
import 'package:on_this_day_mobile/features/quiz/presentation/quiz_session_state.dart';
import '../support/session_fakes.dart';
import '../support/quiz_gameplay_harness.dart';

class FakeLauncher implements SourceLauncher {
  int calls = 0;
  Future<bool> Function() response = () async => true;
  @override
  Future<bool> open(Uri url) {
    calls++;
    return response();
  }
}

void main() {
  late FakeSessionClock clock;
  late FakeSessionScheduler scheduler;
  late QuizSessionController controller;
  late FakeLauncher launcher;
  late List<QuizResult> results;
  late int exits;
  final captureKey = GlobalKey();
  setUp(() {
    clock = FakeSessionClock();
    scheduler = FakeSessionScheduler();
    launcher = FakeLauncher();
    results = [];
    exits = 0;
  });
  Future<void> mount(
    WidgetTester tester, {
    bool daily = false,
    bool timed = true,
    Future<void> Function(QuizResult)? sink,
    double scale = 1,
    Size size = const Size(390, 844),
    QuizQuestionType type = QuizQuestionType.multipleChoice,
  }) async {
    tester.view.physicalSize = size;
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final questions = [for (var i = 0; i < 5; i++) sessionQuestion(i, type)];
    final QuizDefinition quiz = daily
        ? DailyQuizDefinition(
            questionCount: 5,
            questions: questions,
            challengeId: 'daily-test',
            date: QuizDate('2026-09-13'),
            displayDate: 'Sep 13',
            duration: const Duration(seconds: 120),
          )
        : QuickPlayQuizDefinition(
            questionCount: 5,
            questions: questions,
            selection: QuizSelection(displayName: 'Mixed'),
            questionTimeLimits: {
              for (final q in questions)
                q.id: Duration(
                  seconds: type == QuizQuestionType.chronologicalOrdering
                      ? 45
                      : 20,
                ),
            },
            timingEnabledByDefault: true,
          );
    final preparation = FakePreparation();
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.light,
        builder: (context, child) => MediaQuery(
          data: MediaQuery.of(
            context,
          ).copyWith(textScaler: TextScaler.linear(scale)),
          child: child!,
        ),
        home: RepaintBoundary(
          key: captureKey,
          child: QuizGameplayHarness(
            createController: () {
              controller = QuizSessionController(
                definition: quiz,
                completionId: 'test',
                timingEnabled: timed,
                clock: clock,
                scheduler: scheduler,
                prepareSession: preparation.call,
                completionSink: sink ?? (_) async {},
              );
              return controller;
            },
            launcher: launcher,
            onExit: () {
              expect(
                controller.state,
                anyOf(isA<QuizAbandoned>(), isA<QuizCompleted>()),
              );
              exits++;
            },
            onResults: results.add,
          ),
        ),
      ),
    );
    final prepared = controller.prepare();
    preparation.succeed();
    await prepared;
    controller.start();
    await tester.pump();
  }

  Future<void> tap(WidgetTester tester, String text) async {
    await tester.tap(find.text(text));
    await tester.pump();
  }

  testWidgets(
    'immediate incorrect choice labels selection and correct answer; locks input',
    (tester) async {
      await mount(tester);
      expect(find.text('Submit answer'), findsNothing);
      await tap(tester, 'Option b');
      expect(find.text('Your choice'), findsOneWidget);
      expect(find.text('Correct answer'), findsOneWidget);
      expect(find.text('Incorrect'), findsOneWidget);
      await tap(tester, 'Option a');
      expect(find.text('Incorrect'), findsOneWidget);
      await tester.tap(find.text('Continue'));
      await tester.tap(find.text('Continue'));
      await tester.pump();
      expect((controller.state as QuizAnswering).index, 1);
    },
  );
  testWidgets('true false timeout selects nothing, stops and waits', (
    tester,
  ) async {
    await mount(tester, type: QuizQuestionType.trueFalse);
    clock.advance(const Duration(seconds: 20));
    scheduler.fire();
    await tester.pump();
    expect(find.text("Time's up"), findsOneWidget);
    expect(find.text('Your choice'), findsNothing);
    expect(find.text('Correct answer'), findsOneWidget);
    expect(find.byKey(const Key('quiz-timer')), findsNothing);
    clock.advance(const Duration(hours: 1));
    scheduler.fire();
    await tester.pump();
    expect(find.text('Question 1 of 5'), findsOneWidget);
    await tap(tester, 'Continue');
    expect(find.text('Question 2 of 5'), findsOneWidget);
  });
  testWidgets(
    'Daily expiry keeps context and pending result accessible exactly once',
    (tester) async {
      final pending = Completer<void>();
      await mount(tester, daily: true, sink: (_) => pending.future);
      await tap(tester, 'Option a');
      expect(find.text('The reviewed explanation.'), findsNothing);
      clock.advance(const Duration(seconds: 120));
      scheduler.fire();
      await tester.pump();
      expect(find.text("Time's up"), findsOneWidget);
      expect(find.text('Question 1 of 5'), findsOneWidget);
      expect(find.byKey(const Key('quiz-timer')), findsNothing);
      await tester.tap(find.text('View results'));
      await tester.tap(find.text('View results'));
      await tester.pump();
      expect(results, hasLength(1));
      expect(results.single.answered, 1);
      pending.complete();
      await tester.pump();
    },
  );
  testWidgets(
    'failed final delivery still offers results with final feedback',
    (tester) async {
      await mount(tester, sink: (_) async => throw StateError('failed'));
      for (var i = 0; i < 5; i++) {
        await tap(tester, 'Option a');
        if (i < 4) await tap(tester, 'Continue');
      }
      await tester.pump();
      expect(find.text('Correct'), findsOneWidget);
      await tap(tester, 'View results');
      expect(results, hasLength(1));
      expect(find.textContaining('official'), findsNothing);
      expect(find.textContaining('saved'), findsNothing);
    },
  );
  testWidgets('source false and throw recover without losing feedback', (
    tester,
  ) async {
    await mount(tester);
    await tap(tester, 'Option a');
    launcher.response = () async => false;
    await tester.ensureVisible(find.text('Test museum'));
    await tap(tester, 'Test museum');
    expect(find.textContaining('Could not open source'), findsOneWidget);
    launcher.response = () async => throw StateError('no browser');
    await tap(tester, 'Test museum');
    expect(controller.state, isA<QuizFeedback>());
    launcher.response = () async => true;
    await tap(tester, 'Test museum');
    expect(find.textContaining('Could not open source'), findsNothing);
    expect(launcher.calls, 3);
  });
  testWidgets(
    'exit confirmation keeps timer running and abandons before callback',
    (tester) async {
      await mount(tester);
      await tester.tap(find.byTooltip('Leave quiz'));
      await tester.pumpAndSettle();
      expect(scheduler.activeCount, 1);
      await tap(tester, 'Leave');
      await tester.pumpAndSettle();
      expect(exits, 1);
    },
  );
  testWidgets('expiry inside exit confirmation does not discard result', (
    tester,
  ) async {
    await mount(tester, daily: true);
    await tester.tap(find.byTooltip('Leave quiz'));
    await tester.pumpAndSettle();
    clock.advance(const Duration(seconds: 120));
    scheduler.fire();
    await tester.pump();
    await tap(tester, 'Stay');
    await tester.pumpAndSettle();
    expect(find.text('View results'), findsOneWidget);
    expect(exits, 0);
  });
  testWidgets(
    'untimed and timer refresh preserve scrolling; Continue resets heading',
    (tester) async {
      await mount(tester, scale: 2, size: const Size(320, 568));
      await tester.drag(
        find.byType(SingleChildScrollView),
        const Offset(0, -200),
      );
      await tester.pump();
      final position = tester
          .state<ScrollableState>(find.byType(Scrollable).first)
          .position;
      final offset = position.pixels;
      clock.advance(const Duration(seconds: 1));
      scheduler.fire();
      await tester.pump();
      expect(position.pixels, offset);
      await tester.ensureVisible(find.text('Option a'));
      await tap(tester, 'Option a');
      await tap(tester, 'Continue');
      await tester.pump();
      expect(position.pixels, 0);
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox());
      await mount(tester, timed: false);
      expect(find.byKey(const Key('quiz-timer')), findsNothing);
    },
  );
  testWidgets(
    'answer semantics distinguish correctness and do not announce each tick',
    (tester) async {
      final semantics = tester.ensureSemantics();
      await mount(tester, daily: true);
      await tap(tester, 'Option b');
      final live = find.byWidgetPredicate(
        (w) => w is Semantics && w.properties.liveRegion == true,
      );
      expect(tester.widget<Semantics>(live).properties.label, 'Incorrect');
      clock.advance(const Duration(seconds: 1));
      scheduler.fire();
      await tester.pump();
      expect(tester.widget<Semantics>(live).properties.label, 'Incorrect');
      expect(find.text('Your choice'), findsOneWidget);
      expect(find.text('Correct answer'), findsOneWidget);
      semantics.dispose();
    },
  );
  testWidgets(
    'ordering starts in API order and supports accessible boundary moves',
    (tester) async {
      final semantics = tester.ensureSemantics();
      await mount(tester, type: QuizQuestionType.chronologicalOrdering);
      expect(find.text('Question time 00:45'), findsOneWidget);
      expect(find.byKey(const ValueKey('d')), findsOneWidget);
      expect(find.byKey(const ValueKey('b')), findsOneWidget);
      expect(
        tester
            .widget<IconButton>(find.byKey(const Key('Move Item d up')))
            .onPressed,
        isNull,
      );
      expect(
        tester
            .widget<IconButton>(find.byKey(const Key('Move Item c down')))
            .onPressed,
        isNull,
      );
      await tester.tap(find.byKey(const Key('Move Item a up')));
      await tester.pump();
      await tester.tap(find.byKey(const Key('Move Item a up')));
      await tester.pump();
      expect(
        tester.getTopLeft(find.byKey(const ValueKey('a'))).dy,
        lessThan(tester.getTopLeft(find.byKey(const ValueKey('b'))).dy),
      );
      expect(find.byTooltip('Move Item a down'), findsOneWidget);
      semantics.dispose();
    },
  );
  testWidgets('ordering drag and buttons produce controller draft updates', (
    tester,
  ) async {
    await mount(tester, type: QuizQuestionType.chronologicalOrdering);
    final handle = find.byKey(const Key('ordering-drag-d'));
    final gesture = await tester.startGesture(tester.getCenter(handle));
    await tester.pump();
    await gesture.moveBy(const Offset(0, 300));
    await tester.pump();
    await gesture.up();
    await tester.pumpAndSettle();
    expect(
      (controller.state as QuizAnswering).orderingDraft,
      isNot(['d', 'b', 'a', 'c']),
    );
    await tester.tap(find.byKey(const Key('Move Item a up')));
    await tester.pump();
    expect(controller.state, isA<QuizAnswering>());
  });
  testWidgets('ordering submission is explicit and renders vertical feedback', (
    tester,
  ) async {
    await mount(tester, type: QuizQuestionType.chronologicalOrdering);
    await tester.tap(find.byKey(const Key('submit-order')));
    await tester.pump();
    expect(find.text('Incorrect'), findsOneWidget);
    expect(find.text('Your submitted order'), findsOneWidget);
    expect(find.text('Correct order'), findsOneWidget);
    expect(find.text('The reviewed explanation.'), findsOneWidget);
    expect(find.byKey(const Key('submit-order')), findsNothing);
    await tester.tap(find.text('Continue'));
    await tester.pump();
    expect((controller.state as QuizAnswering).index, 1);
  });
  testWidgets('ordering timeout preserves an unsubmitted draft and waits', (
    tester,
  ) async {
    await mount(tester, type: QuizQuestionType.chronologicalOrdering);
    await tester.tap(find.byKey(const Key('Move Item a up')));
    await tester.pump();
    clock.advance(const Duration(seconds: 45));
    scheduler.fire();
    await tester.pump();
    expect(find.text("Time's up"), findsOneWidget);
    expect(find.text('Your draft - not submitted'), findsOneWidget);
    expect(find.text('Your submitted order'), findsNothing);
    expect(find.text('Correct order'), findsOneWidget);
    expect(find.byKey(const Key('submit-order')), findsNothing);
    await tap(tester, 'Continue');
    expect((controller.state as QuizAnswering).index, 1);
  });
  testWidgets(
    'Daily ordering expiry retains draft context and results access',
    (tester) async {
      await mount(
        tester,
        daily: true,
        type: QuizQuestionType.chronologicalOrdering,
      );
      await tester.tap(find.byKey(const Key('Move Item a up')));
      await tester.pump();
      clock.advance(const Duration(seconds: 120));
      scheduler.fire();
      await tester.pump();
      expect(find.text("Time's up"), findsOneWidget);
      expect(find.text('Your draft - not submitted'), findsOneWidget);
      expect(find.text('View results'), findsOneWidget);
      expect(find.byKey(const Key('submit-order')), findsNothing);
    },
  );
  testWidgets('untimed ordering hides time and large text can reach controls', (
    tester,
  ) async {
    await mount(
      tester,
      timed: false,
      scale: 2,
      size: const Size(320, 568),
      type: QuizQuestionType.chronologicalOrdering,
    );
    expect(find.byKey(const Key('quiz-timer')), findsNothing);
    await tester.ensureVisible(find.byKey(const Key('Move Item a up')));
    expect(find.byKey(const Key('Move Item a up')), findsOneWidget);
    await tester.ensureVisible(find.byKey(const Key('submit-order')));
    expect(find.text('Submit order'), findsOneWidget);
  });
  testWidgets('late source failure after advancing or disposal is harmless', (
    tester,
  ) async {
    await mount(tester);
    await tap(tester, 'Option a');
    final pending = Completer<bool>();
    launcher.response = () => pending.future;
    await tester.ensureVisible(find.text('Test museum'));
    await tap(tester, 'Test museum');
    await tap(tester, 'Continue');
    pending.completeError(StateError('late browser failure'));
    await tester.pump();
    expect(find.textContaining('Could not open source'), findsNothing);
    expect((controller.state as QuizAnswering).index, 1);
    await tap(tester, 'Option a');
    final disposed = Completer<bool>();
    launcher.response = () => disposed.future;
    await tester.ensureVisible(find.text('Test museum'));
    await tap(tester, 'Test museum');
    await tester.pumpWidget(const SizedBox());
    disposed.complete(false);
    await tester.pump();
    expect(tester.takeException(), isNull);
  });
  testWidgets('representative real-widget screenshots', (tester) async {
    const destination = String.fromEnvironment('QUIZ_SCREENSHOT_DIR');
    if (destination.isEmpty) return;
    // Optional local font loading makes captures readable rather than Ahem boxes.
    for (final entry in {
      'Roboto': '/System/Library/Fonts/Supplemental/Arial.ttf',
      'Georgia': '/System/Library/Fonts/Supplemental/Georgia.ttf',
      'MaterialIcons':
          '${Platform.environment['FLUTTER_ROOT']}/bin/cache/artifacts/material_fonts/MaterialIcons-Regular.otf',
    }.entries) {
      final bytes = await tester.runAsync(
        () => File(entry.value).readAsBytes(),
      );
      final loader = FontLoader(entry.key)
        ..addFont(Future.value(ByteData.sublistView(bytes!)));
      await loader.load();
    }
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

    await mount(tester, daily: true);
    await capture('answering');
    await tap(tester, 'Option b');
    await capture('incorrect');
    await tester.pumpWidget(const SizedBox());
    await mount(tester, type: QuizQuestionType.trueFalse);
    clock.advance(const Duration(seconds: 20));
    scheduler.fire();
    await tester.pump();
    await capture('timeout');
    await tester.pumpWidget(const SizedBox());
    await mount(tester, scale: 2, size: const Size(320, 568));
    await capture('large-text');
    await tester.ensureVisible(find.text('Option b'));
    await tap(tester, 'Option b');
    await capture('large-text-feedback');
    await tester.pumpWidget(const SizedBox());
    await mount(tester, type: QuizQuestionType.chronologicalOrdering);
    await capture('ordering-initial');
    await tester.tap(find.byKey(const Key('Move Item a up')));
    await tester.pump();
    await capture('ordering-rearranged');
    await tester.tap(find.byKey(const Key('submit-order')));
    await tester.pump();
    await capture('ordering-incorrect');
    await tester.pumpWidget(const SizedBox());
    await mount(tester, type: QuizQuestionType.chronologicalOrdering);
    for (final key in const [
      Key('Move Item a up'),
      Key('Move Item a up'),
      Key('Move Item d down'),
      Key('Move Item d down'),
    ]) {
      await tester.tap(find.byKey(key));
      await tester.pump();
    }
    await tester.tap(find.byKey(const Key('submit-order')));
    await tester.pump();
    await capture('ordering-correct');
    await tester.pumpWidget(const SizedBox());
    await mount(tester, type: QuizQuestionType.chronologicalOrdering);
    clock.advance(const Duration(seconds: 45));
    scheduler.fire();
    await tester.pump();
    await capture('ordering-timeout');
    await tester.pumpWidget(const SizedBox());
    await mount(
      tester,
      type: QuizQuestionType.chronologicalOrdering,
      scale: 2,
      size: const Size(320, 568),
    );
    await capture('ordering-large-text');
    expect(tester.takeException(), isNull);
  });
}
