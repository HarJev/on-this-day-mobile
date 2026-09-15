import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:on_this_day_mobile/features/quiz/application/quiz_completion_coordinator.dart';
import 'package:on_this_day_mobile/features/quiz/domain/question_outcome.dart';
import 'package:on_this_day_mobile/features/quiz/domain/quiz_answer.dart';
import 'package:on_this_day_mobile/features/quiz/domain/quiz_definition.dart';
import 'package:on_this_day_mobile/features/quiz/domain/quiz_question.dart';
import 'package:on_this_day_mobile/features/quiz/domain/quiz_result.dart';
import 'package:on_this_day_mobile/features/quiz/domain/quiz_result_store.dart';

import '../support/session_fakes.dart';

void main() {
  test('shares one in-flight operation for a completion ID', () async {
    final store = _ControlledStore();
    final coordinator = QuizCompletionCoordinator(store);
    final frozenCompletion = _completion('same');

    final first = coordinator.complete(frozenCompletion);
    final second = coordinator.complete(frozenCompletion);

    expect(identical(first, second), isTrue);
    expect(store.calls, 1);
    store.succeed(QuizSavedClassification.official);
    await expectLater(first, completion(isA<StoredQuizResult>()));
    expect(
      coordinator.stateFor('same')!.status,
      QuizCompletionSaveStatus.saved,
    );
  });

  test('listeners can safely reread an in-flight completion', () async {
    final store = _ControlledStore();
    final coordinator = QuizCompletionCoordinator(store);
    final completion = _completion('reentrant');
    Future<StoredQuizResult>? reread;
    coordinator.addListener(() => reread ??= coordinator.complete(completion));

    final original = coordinator.complete(completion);

    expect(identical(original, reread), isTrue);
    expect(store.calls, 1);
    store.succeed(QuizSavedClassification.official);
    await original;
  });

  test(
    'a second Daily completion becomes practice while the claim is pending',
    () {
      final store = _ControlledStore();
      final coordinator = QuizCompletionCoordinator(store);

      coordinator.complete(_completion('first'));
      coordinator.complete(_completion('second'));

      expect(store.completions.map((item) => item.intent), [
        QuizSaveIntent.claimDailyIfAbsent,
        QuizSaveIntent.practice,
      ]);
      expect(
        coordinator.stateFor('second')!.effectiveIntent,
        QuizSaveIntent.practice,
      );
    },
  );

  test(
    'a completed claim that resolves practice keeps the date occupied',
    () async {
      final store = _ControlledStore();
      final coordinator = QuizCompletionCoordinator(store);
      final first = coordinator.complete(_completion('first'));
      store.succeed(QuizSavedClassification.practice);
      await first;

      coordinator.complete(_completion('later'));

      expect(store.completions.last.intent, QuizSaveIntent.practice);
    },
  );

  test(
    'exposes an immutable Daily reservation snapshot by backend date',
    () async {
      final store = _ControlledStore();
      final coordinator = QuizCompletionCoordinator(store);
      final date = QuizDate('2026-09-13');

      final operation = coordinator.complete(_completion('snapshot'));
      expect(
        coordinator.dailyReservationFor(date)?.status,
        QuizCompletionSaveStatus.pending,
      );
      expect(coordinator.dailyReservationFor(date)?.classification, isNull);

      store.succeed(QuizSavedClassification.practice);
      await operation;

      final snapshot = coordinator.dailyReservationFor(date)!;
      expect(snapshot.status, QuizCompletionSaveStatus.saved);
      expect(snapshot.classification, QuizSavedClassification.practice);
    },
  );

  test('retry uses the same frozen completion and effective intent', () async {
    final store = _ControlledStore();
    final coordinator = QuizCompletionCoordinator(store);
    final first = coordinator.complete(_completion('retry'));
    store.fail(StateError('disk unavailable'));
    await expectLater(first, throwsStateError);

    final retry = coordinator.retry('retry');
    expect(store.completions.length, 2);
    expect(store.completions[1].result, same(store.completions[0].result));
    expect(store.completions[1].intent, QuizSaveIntent.claimDailyIfAbsent);
    store.succeed(QuizSavedClassification.official);
    await retry;
  });

  test(
    'keeps an in-flight save alive after disposal without late listeners',
    () async {
      final store = _ControlledStore();
      final coordinator = QuizCompletionCoordinator(store);
      var notifications = 0;
      coordinator.addListener(() => notifications++);

      final operation = coordinator.complete(_completion('dispose'));
      expect(notifications, 1);

      coordinator.dispose();
      store.succeed(QuizSavedClassification.official);

      await expectLater(operation, completion(isA<StoredQuizResult>()));
      expect(
        coordinator.stateFor('dispose')!.status,
        QuizCompletionSaveStatus.saved,
      );
      expect(notifications, 1);
    },
  );
}

final class _ControlledStore implements QuizResultStore {
  final completions = <QuizCompletion>[];
  final _pending = <Completer<StoredQuizResult>>[];
  int get calls => completions.length;

  @override
  Future<StoredQuizResult> saveCompletion(QuizCompletion completion) {
    completions.add(completion);
    final pending = Completer<StoredQuizResult>();
    _pending.add(pending);
    return pending.future;
  }

  void succeed(QuizSavedClassification classification) {
    final completion =
        completions[_pending.indexWhere((item) => !item.isCompleted)];
    _pending
        .firstWhere((item) => !item.isCompleted)
        .complete(StoredQuizResult(completion.result, classification));
  }

  void fail(Object error) =>
      _pending.firstWhere((item) => !item.isCompleted).completeError(error);

  @override
  Future<StoredQuizResult?> getBestResult(QuizBestResultKey key) async => null;
  @override
  Future<StoredQuizResult?> getOfficialDaily(QuizDate date) async => null;
  @override
  Future<bool> getQuickPlayTimingEnabled() async => true;
  @override
  Future<void> setQuickPlayTimingEnabled(bool enabled) async {}
}

QuizCompletion _completion(String id) {
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
