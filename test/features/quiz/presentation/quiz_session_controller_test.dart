import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:on_this_day_mobile/features/quiz/domain/question_outcome.dart';
import 'package:on_this_day_mobile/features/quiz/domain/quiz_question.dart';
import 'package:on_this_day_mobile/features/quiz/domain/quiz_result.dart';
import 'package:on_this_day_mobile/features/quiz/domain/quiz_rules.dart';
import 'package:on_this_day_mobile/features/quiz/presentation/quiz_session_controller.dart';
import 'package:on_this_day_mobile/features/quiz/presentation/quiz_session_state.dart';

import '../support/session_fakes.dart';

void main() {
  late FakeSessionClock clock;
  late FakeSessionScheduler scheduler;
  late FakePreparation preparation;
  late List<QuizResult> completions;
  late QuizSessionController controller;

  QuizSessionController create({
    bool daily = false,
    bool timed = true,
    QuizQuestionType last = QuizQuestionType.multipleChoice,
    Future<void> Function(QuizResult)? sink,
  }) {
    controller = QuizSessionController(
      definition: sessionQuiz(daily: daily, last: last),
      completionId: 'test-completion',
      timingEnabled: timed,
      clock: clock,
      scheduler: scheduler,
      prepareSession: preparation.call,
      completionSink:
          sink ??
          (r) async {
            completions.add(r);
          },
    );
    addTearDown(controller.dispose);
    return controller;
  }

  Future<void> start() async {
    final future = controller.prepare();
    preparation.succeed();
    await future;
    controller.start();
  }

  void answer() {
    final s = controller.state as QuizAnswering;
    final q = s.question;
    if (q is ChoiceQuestion) {
      controller.answerOption(q.id, q.correctOptionId);
    } else {
      controller.updateOrderingDraft(
        q.id,
        (q as ChronologicalOrderingQuestion).correctOrderItemIds,
      );
      controller.submitOrder(q.id);
    }
  }

  void next() {
    final s = controller.state as QuizFeedback;
    controller.continueQuiz(s.outcome.question.id);
  }

  void reachLast() {
    for (var i = 0; i < 4; i++) {
      answer();
      next();
    }
  }

  setUp(() {
    clock = FakeSessionClock();
    scheduler = FakeSessionScheduler();
    preparation = FakePreparation();
    completions = [];
  });

  test(
    'preparation factory reentrant disposal cancels and releases late lease',
    () async {
      controller = QuizSessionController(
        definition: sessionQuiz(),
        completionId: 'factory-disposal',
        timingEnabled: true,
        clock: clock,
        scheduler: scheduler,
        prepareSession: (quiz) {
          final attempt = preparation.call(quiz);
          controller.dispose();
          return attempt;
        },
        completionSink: (_) async {},
      );
      final pending = controller.prepare();
      expect(preparation.cancellations, 1);
      preparation.succeed();
      await pending;
      expect(preparation.releases, 1);
    },
  );
  test('both clocks count their maximum, never their sum', () async {
    create(daily: true);
    await start();
    controller.setAppActive(false);
    clock.advance(const Duration(seconds: 4), wall: const Duration(seconds: 6));
    controller.setRouteVisible(false);
    clock.advance(const Duration(seconds: 3));
    controller.setAppActive(true);
    controller.setRouteVisible(true);
    expect(
      (controller.state as QuizAnswering).remaining,
      const Duration(seconds: 11),
    );
  });
  test(
    'Quick Play covered feedback does not consume the following budget',
    () async {
      create();
      await start();
      answer();
      controller.setRouteVisible(false);
      clock.advance(const Duration(hours: 1));
      controller.continueQuiz('q-0');
      expect(controller.state, isA<QuizFeedback>());
      controller.setRouteVisible(true);
      next();
      expect(
        (controller.state as QuizAnswering).remaining,
        const Duration(seconds: 20),
      );
    },
  );
  test('Daily final-answer deadline freezes a timeout exactly once', () async {
    create(daily: true);
    await start();
    reachLast();
    clock.advance(const Duration(seconds: 20));
    answer();
    scheduler.fire();
    final r = completions.single;
    expect(r.reason, QuizCompletionReason.dailyTimeExpired);
    expect(r.correct, 4);
    expect(r.outcomes.last.kind, QuestionOutcomeKind.timedOut);
  });
  test(
    'final answer before deadline cannot be replaced by a queued expiry',
    () async {
      create(daily: true);
      await start();
      reachLast();
      final queued = scheduler.ticks.last;
      clock.advance(const Duration(seconds: 19));
      answer();
      clock.advance(const Duration(seconds: 1));
      queued.callback();
      expect(completions.single.reason, QuizCompletionReason.questionsFinished);
      expect(completions.single.correct, 5);
    },
  );
  test(
    'late asynchronous sink failure after disposal is handled silently',
    () async {
      final sink = Completer<void>();
      create(
        sink: (r) {
          completions.add(r);
          return sink.future;
        },
      );
      await start();
      reachLast();
      answer();
      controller.dispose();
      sink.completeError(StateError('late failure'));
      await Future<void>.delayed(Duration.zero);
      expect(completions.length, 1);
    },
  );
  test(
    'completion listener disposal does not prevent sink invocation',
    () async {
      create();
      await start();
      reachLast();
      controller.addListener(() {
        if (controller.state is QuizCompleted) controller.dispose();
      });
      answer();
      expect(completions.length, 1);
      await Future<void>.value();
    },
  );

  test('preparation and ready consume no time and start is explicit', () async {
    create();
    expect(preparation.pending, isEmpty);
    controller.start();
    final pending = controller.prepare();
    clock.advance(const Duration(hours: 1));
    expect(scheduler.ticks, isEmpty);
    preparation.succeed();
    await pending;
    expect(controller.state, isA<QuizReady>());
    clock.advance(const Duration(hours: 1));
    controller.start();
    expect(
      (controller.state as QuizAnswering).remaining,
      const Duration(seconds: 20),
    );
    expect(scheduler.activeCount, 1);
    controller.start();
    expect(scheduler.activeCount, 1);
  });
  test(
    'preparation failure retries; stale success releases exactly once',
    () async {
      create();
      final old = controller.prepare();
      final current = controller.prepare();
      expect(preparation.cancellations, 1);
      final staleLease = preparation.succeed(0);
      await old;
      expect(preparation.releases, 1);
      staleLease.release();
      expect(preparation.releases, 1);
      preparation.pending[1].completeError(StateError('failed'));
      await current;
      expect(controller.state, isA<QuizPreparationFailed>());
      final retry = controller.prepare();
      preparation.succeed();
      await retry;
      expect(controller.state, isA<QuizReady>());
    },
  );
  test(
    'stale preparation failure cannot replace a newer ready state',
    () async {
      create();
      final old = controller.prepare();
      final current = controller.prepare();
      preparation.succeed(1);
      await current;
      preparation.pending[0].completeError(StateError('stale'));
      await old;
      expect(controller.state, isA<QuizReady>());
    },
  );
  test(
    'choice commits immediately, locks and ignores stale question callbacks',
    () async {
      create();
      await start();
      controller.answerOption('q-0', 'a');
      controller.answerOption('q-0', 'b');
      expect(
        (controller.state as QuizFeedback).outcome.kind,
        QuestionOutcomeKind.correct,
      );
      next();
      controller.answerOption('q-0', 'a');
      controller.continueQuiz('q-0');
      expect((controller.state as QuizAnswering).index, 1);
    },
  );
  for (final daily in [false, true]) {
    test(
      '${daily ? 'Daily' : 'Quick Play'} exact deadline beats an answer without ticker',
      () async {
        create(daily: daily);
        await start();
        clock.advance(const Duration(seconds: 20));
        controller.answerOption('q-0', 'a');
        if (daily) {
          final r = (controller.state as QuizCompleted).result;
          expect(r.outcomes.first.kind, QuestionOutcomeKind.timedOut);
          expect(
            r.outcomes
                .skip(1)
                .every(
                  (o) => o.unansweredReason == UnansweredReason.notReached,
                ),
            isTrue,
          );
        } else {
          expect(
            (controller.state as QuizFeedback).outcome.kind,
            QuestionOutcomeKind.timedOut,
          );
          expect(completions, isEmpty);
        }
      },
    );
  }
  test('Daily feedback continues; committed answer survives expiry', () async {
    create(daily: true);
    await start();
    answer();
    clock.advance(const Duration(seconds: 5));
    scheduler.fire();
    expect(
      (controller.state as QuizFeedback).remaining,
      const Duration(seconds: 15),
    );
    clock.advance(const Duration(seconds: 15));
    scheduler.fire();
    expect(completions.single.outcomes.first.kind, QuestionOutcomeKind.correct);
    expect(
      completions.single.outcomes[1].unansweredReason,
      UnansweredReason.notReached,
    );
  });
  test(
    'Quick Play feedback stops and hidden Continue starts nothing',
    () async {
      create();
      await start();
      answer();
      expect(scheduler.activeCount, 0);
      controller.setAppActive(false);
      clock.advance(const Duration(hours: 1));
      controller.continueQuiz('q-0');
      expect(controller.state, isA<QuizFeedback>());
      controller.setAppActive(true);
      next();
      expect(
        (controller.state as QuizAnswering).remaining,
        const Duration(seconds: 20),
      );
    },
  );
  for (final routeFirst in [false, true]) {
    test(
      'overlapping hidden signals routeFirst=$routeFirst use one baseline',
      () async {
        create(daily: true);
        await start();
        clock.advance(const Duration(seconds: 2));
        if (routeFirst) {
          controller.setRouteVisible(false);
        } else {
          controller.setAppActive(false);
        }
        expect(scheduler.activeCount, 0);
        clock.advance(Duration.zero, wall: const Duration(seconds: 3));
        if (routeFirst) {
          controller.setAppActive(false);
        } else {
          controller.setRouteVisible(false);
        }
        clock.advance(Duration.zero, wall: const Duration(seconds: 4));
        if (routeFirst) {
          controller.setRouteVisible(true);
        } else {
          controller.setAppActive(true);
        }
        expect(scheduler.activeCount, 0);
        clock.advance(Duration.zero, wall: const Duration(seconds: 5));
        if (routeFirst) {
          controller.setAppActive(true);
        } else {
          controller.setRouteVisible(true);
        }
        expect(
          (controller.state as QuizAnswering).remaining,
          const Duration(seconds: 6),
        );
        expect(scheduler.activeCount, 1);
        controller.setAppActive(true);
        controller.setRouteVisible(true);
        expect(
          (controller.state as QuizAnswering).remaining,
          const Duration(seconds: 6),
        );
      },
    );
  }
  test(
    'backwards wall time never grants time and forward hidden jump expires',
    () async {
      create();
      await start();
      controller.setRouteVisible(false);
      clock.advance(
        const Duration(seconds: 5),
        wall: const Duration(hours: -1),
      );
      controller.setRouteVisible(true);
      expect(
        (controller.state as QuizAnswering).remaining,
        const Duration(seconds: 15),
      );
      controller.setRouteVisible(false);
      clock.advance(Duration.zero, wall: const Duration(hours: 2));
      controller.setRouteVisible(true);
      expect(
        (controller.state as QuizFeedback).outcome.kind,
        QuestionOutcomeKind.timedOut,
      );
    },
  );
  test('untimed Quick Play never schedules or times out', () async {
    create(timed: false);
    await start();
    controller.setRouteVisible(false);
    clock.advance(const Duration(days: 1));
    controller.setRouteVisible(true);
    expect((controller.state as QuizAnswering).remaining, isNull);
    expect(scheduler.ticks, isEmpty);
    reachLast();
    answer();
    expect(completions.single.timingEnabled, isFalse);
  });
  test(
    'ordering draft stays separate and is never submitted on timeout',
    () async {
      create();
      await start();
      for (var i = 0; i < 3; i++) {
        answer();
        next();
      }
      controller.updateOrderingDraft('q-3', ['a', 'b', 'c', 'd']);
      expect(controller.state, isA<QuizAnswering>());
      clock.advance(const Duration(seconds: 20));
      controller.submitOrder('q-3');
      final outcome = (controller.state as QuizFeedback).outcome;
      expect(outcome.kind, QuestionOutcomeKind.timedOut);
      expect(outcome.answer, isNull);
    },
  );
  for (final finish in ['answer', 'skip', 'timeout']) {
    test(
      'final $finish freezes and sends once before results navigation',
      () async {
        create(
          last: finish == 'skip'
              ? QuizQuestionType.imageIdentification
              : QuizQuestionType.multipleChoice,
        );
        await start();
        reachLast();
        switch (finish) {
          case 'answer':
            answer();
          case 'skip':
            controller.skipImage('q-4');
          case 'timeout':
            clock.advance(const Duration(seconds: 20));
            scheduler.fire();
        }
        final result = (controller.state as QuizCompleted).result;
        expect(completions.single, same(result));
        controller.answerOption('q-4', 'a');
        controller.skipImage('q-4');
        controller.continueQuiz('q-4');
        controller.abandon();
        controller.interrupt(StateError('late'));
        expect((controller.state as QuizCompleted).result, same(result));
        expect(completions.length, 1);
        expect(scheduler.activeCount, 0);
        expect(preparation.releases, finish == 'skip' ? 0 : 1);
        controller.dispose();
        expect(preparation.releases, 1);
      },
    );
  }
  test(
    'reentrant sink observes terminal guard before invoking any action',
    () async {
      create(
        sink: (r) {
          completions.add(r);
          expect(controller.state, isA<QuizCompleted>());
          controller.answerOption('q-4', 'b');
          controller.abandon();
          controller.interrupt('late');
          scheduler.fire();
          return Future.value();
        },
      );
      await start();
      reachLast();
      answer();
      await Future<void>.value();
      expect(completions.length, 1);
      expect(
        (controller.state as QuizCompleted).delivery,
        QuizCompletionDelivery.delivered,
      );
    },
  );
  for (final synchronous in [true, false]) {
    test(
      'sink failure synchronous=$synchronous preserves completion',
      () async {
        final failure = StateError('save failed');
        create(
          sink: (_) {
            if (synchronous) throw failure;
            return Future.error(failure);
          },
        );
        await start();
        reachLast();
        answer();
        await Future<void>.delayed(Duration.zero);
        final completed = controller.state as QuizCompleted;
        expect(completed.delivery, QuizCompletionDelivery.failed);
        expect(completed.deliveryError, same(failure));
        controller.answerOption('q-4', 'b');
        expect(
          (controller.state as QuizCompleted).result,
          same(completed.result),
        );
      },
    );
  }
  test('disposal inside sink cannot cancel already-started delivery', () async {
    final sink = Completer<void>();
    create(
      sink: (r) {
        completions.add(r);
        controller.dispose();
        return sink.future;
      },
    );
    await start();
    reachLast();
    var notifications = 0;
    controller.addListener(() => notifications++);
    answer();
    sink.complete();
    await Future<void>.value();
    expect(completions.length, 1);
    expect(notifications, 0);
  });
  test(
    'abandonment and technical interruption are unscored and idempotent',
    () async {
      create();
      await start();
      controller.abandon();
      controller.interrupt('later');
      expect(controller.state, isA<QuizAbandoned>());
      expect(completions, isEmpty);
      expect(preparation.releases, 1);
      controller.dispose();
      expect(preparation.releases, 1);
    },
  );
  test(
    'technical interruption releases resources without scored completion',
    () async {
      create();
      await start();
      controller.interrupt('image unavailable');
      expect(controller.state, isA<QuizInterrupted>());
      expect(completions, isEmpty);
      expect(scheduler.activeCount, 0);
      expect(preparation.releases, 1);
    },
  );
  test(
    'disposed preparation result still releases resources without notifying',
    () async {
      create();
      final pending = controller.prepare();
      var notifications = 0;
      controller.addListener(() => notifications++);
      controller.dispose();
      preparation.succeed();
      await pending;
      expect(notifications, 0);
      expect(preparation.releases, 1);
      expect(preparation.cancellations, 1);
    },
  );
  test('cancelled and disposed scheduled callbacks are inert', () async {
    create();
    await start();
    final stale = scheduler.ticks.single;
    controller.setRouteVisible(false);
    clock.advance(const Duration(seconds: 30));
    stale.callback();
    expect(controller.state, isA<QuizAnswering>());
    controller.setRouteVisible(true);
    expect(controller.state, isA<QuizFeedback>());
    controller.dispose();
    stale.callback();
    expect(completions, isEmpty);
  });
}
