import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:on_this_day_mobile/features/quiz/domain/question_outcome.dart';
import 'package:on_this_day_mobile/features/quiz/domain/quiz_result.dart';
import 'package:on_this_day_mobile/features/quiz/presentation/quiz_session_controller.dart';
import 'package:on_this_day_mobile/features/quiz/presentation/quiz_session_state.dart';

import '../support/quiz_session_harness.dart';
import '../support/session_fakes.dart';

void main() {
  late FakeSessionClock clock;
  late FakeSessionScheduler scheduler;
  late FakePreparation preparation;
  late QuizSessionController controller;
  late List<QuizResult> completions;
  setUp(() {
    clock = FakeSessionClock();
    scheduler = FakeSessionScheduler();
    preparation = FakePreparation();
    completions = [];
  });
  Future<void> mount(
    WidgetTester tester, {
    bool daily = false,
    bool timed = true,
  }) async {
    await tester.pumpWidget(
      MaterialApp(
        home: QuizSessionHarness(
          createController: () {
            controller = QuizSessionController(
              definition: sessionQuiz(daily: daily),
              completionId: 'widget-session',
              timingEnabled: timed,
              clock: clock,
              scheduler: scheduler,
              prepareSession: preparation.call,
              completionSink: (r) async => completions.add(r),
            );
            return controller;
          },
        ),
      ),
    );
    await tester.tap(find.byKey(const Key('prepare')));
    await tester.pump();
    expect(find.byKey(const Key('timer')), findsNothing);
    preparation.succeed();
    await tester.pump();
    await tester.tap(find.byKey(const Key('start')));
    await tester.pump();
  }

  Future<void> tap(WidgetTester tester, String key) async {
    await tester.tap(find.byKey(Key(key)));
    await tester.pump();
  }

  testWidgets(
    'choice, true/false, image skip, ordering and completion via widgets',
    (tester) async {
      await mount(tester);
      expect(find.text('Submit answer'), findsNothing);
      await tap(tester, 'option-a');
      expect(find.text('Correct'), findsOneWidget);
      expect(find.byKey(const Key('option-b')), findsNothing);
      await tap(tester, 'continue');
      await tap(tester, 'option-false');
      expect(find.text('Incorrect'), findsOneWidget);
      await tap(tester, 'continue');
      await tap(tester, 'skip');
      expect(find.text('Skipped'), findsOneWidget);
      await tap(tester, 'continue');
      await tap(tester, 'up-a');
      await tap(tester, 'up-a');
      await tap(tester, 'up-b');
      await tap(tester, 'up-c');
      expect(controller.state, isA<QuizAnswering>());
      await tap(tester, 'submit-order');
      expect(find.text('Correct'), findsOneWidget);
      await tap(tester, 'continue');
      await tap(tester, 'option-a');
      expect(find.text('Completed'), findsOneWidget);
      expect(completions.single.correct, 3);
      expect(
        completions.single.outcomes[2].unansweredReason,
        UnansweredReason.imageSkipped,
      );
      expect(preparation.releases, 1);
      await tester.pumpWidget(const SizedBox());
    },
  );
  testWidgets(
    'cover route, background, foreground, uncover reconciles before rendering',
    (tester) async {
      await mount(tester);
      await tap(tester, 'cover');
      await tester.pumpAndSettle();
      expect(scheduler.activeCount, 0);
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.paused);
      clock.advance(Duration.zero, wall: const Duration(seconds: 25));
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
      expect(scheduler.activeCount, 0);
      await tap(tester, 'return');
      await tester.pumpAndSettle();
      expect(find.text("Time's up"), findsOneWidget);
      expect(find.byKey(const Key('continue')), findsOneWidget);
      clock.advance(const Duration(hours: 1));
      scheduler.fire();
      await tester.pump();
      expect(find.text('1 / 5'), findsOneWidget);
      await tap(tester, 'continue');
      expect(find.text('Question time 00:20'), findsOneWidget);
      await tester.pumpWidget(const SizedBox());
    },
  );
  testWidgets(
    'Daily feedback excludes explanation and expires while exit confirmation is open',
    (tester) async {
      await mount(tester, daily: true);
      await tap(tester, 'option-a');
      expect(find.text('The reviewed explanation.'), findsNothing);
      await tap(tester, 'exit');
      await tester.pumpAndSettle();
      clock.advance(const Duration(seconds: 20));
      scheduler.fire();
      await tester.pump();
      expect(completions.length, 1);
      await tap(tester, 'confirm-exit');
      await tester.pumpAndSettle();
      expect(find.text('Completed'), findsOneWidget);
      expect(completions.single.correct, 1);
      await tester.pumpWidget(const SizedBox());
    },
  );
  testWidgets('confirmed exit before deadline is unscored', (tester) async {
    await mount(tester);
    await tap(tester, 'exit');
    await tester.pumpAndSettle();
    await tap(tester, 'confirm-exit');
    await tester.pumpAndSettle();
    expect(find.text('Abandoned'), findsOneWidget);
    expect(completions, isEmpty);
    expect(scheduler.activeCount, 0);
    await tester.pumpWidget(const SizedBox());
  });
  testWidgets(
    'untimed harness never shows countdown or schedules display ticks',
    (tester) async {
      await mount(tester, timed: false);
      expect(find.byKey(const Key('timer')), findsNothing);
      expect(scheduler.ticks, isEmpty);
      clock.advance(const Duration(days: 1));
      await tap(tester, 'option-a');
      expect(find.text('Correct'), findsOneWidget);
      await tester.pumpWidget(const SizedBox());
    },
  );
  testWidgets('deadline wins over widget tap even without a tick', (
    tester,
  ) async {
    await mount(tester);
    clock.advance(const Duration(seconds: 20));
    await tap(tester, 'option-a');
    expect(find.text("Time's up"), findsOneWidget);
    expect((controller.state as QuizFeedback).outcome.answer, isNull);
    await tester.pumpWidget(const SizedBox());
  });
}
