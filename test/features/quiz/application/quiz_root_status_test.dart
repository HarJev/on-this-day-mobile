import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:on_this_day_mobile/features/quiz/application/daily_challenge_status.dart';
import 'package:on_this_day_mobile/features/quiz/application/quiz_completion_coordinator.dart';
import 'package:on_this_day_mobile/features/quiz/application/quiz_root_status.dart';
import 'package:on_this_day_mobile/features/quiz/domain/question_outcome.dart';
import 'package:on_this_day_mobile/features/quiz/domain/quiz_answer.dart';
import 'package:on_this_day_mobile/features/quiz/domain/quiz_definition.dart';
import 'package:on_this_day_mobile/features/quiz/domain/quiz_question.dart';
import 'package:on_this_day_mobile/features/quiz/domain/quiz_result.dart';
import 'package:on_this_day_mobile/features/quiz/domain/quiz_result_store.dart';

import '../support/session_fakes.dart';

void main() {
  final date = QuizDate('2026-09-13');
  final resolved = DailyChallengeStatus(date: date, displayDate: 'Sep 13');

  test('a confirmed official Daily publishes its frozen result', () async {
    final store = _ControlledStore();
    final coordinator = QuizCompletionCoordinator(store);
    final status = QuizRootStatus(coordinator)..update(resolved);
    final completion = _completion('official');

    final operation = coordinator.complete(completion);
    expect(status.value!.hasConfirmedOfficial, isFalse);
    expect(status.value!.reservation!.status, QuizCompletionSaveStatus.pending);

    store.succeed(QuizSavedClassification.official);
    await operation;

    final confirmed = status.value!.confirmedOfficialResult!;
    expect(status.value!.displayDate, 'Sep 13');
    expect(confirmed.result, same(completion.result));
    expect(status.value!.blocksOfficialClaim, isTrue);
  });

  test('a failed save stays honest and a retry can confirm it', () async {
    final store = _ControlledStore();
    final coordinator = QuizCompletionCoordinator(store);
    final status = QuizRootStatus(coordinator)..update(resolved);

    final operation = coordinator.complete(_completion('failed'));
    store.fail(StateError('disk unavailable'));
    await expectLater(operation, throwsStateError);

    expect(status.value!.hasConfirmedOfficial, isFalse);
    expect(status.value!.reservation!.status, QuizCompletionSaveStatus.failed);
    expect(status.value!.blocksOfficialClaim, isTrue);

    final retry = coordinator.retry('failed');
    expect(status.value!.reservation!.status, QuizCompletionSaveStatus.pending);
    store.succeed(QuizSavedClassification.official);
    await retry;
    expect(status.value!.hasConfirmedOfficial, isTrue);
  });

  test('a claim stored as practice never shows an official score', () async {
    final store = _ControlledStore();
    final coordinator = QuizCompletionCoordinator(store);
    final status = QuizRootStatus(coordinator)..update(resolved);

    final operation = coordinator.complete(_completion('late-claim'));
    store.succeed(QuizSavedClassification.practice);
    await operation;

    expect(status.value!.hasConfirmedOfficial, isFalse);
    expect(
      status.value!.reservation!.classification,
      QuizSavedClassification.practice,
    );
  });

  test('later practice does not replace a confirmed official result', () async {
    final store = _ControlledStore();
    final coordinator = QuizCompletionCoordinator(store);
    final official = StoredQuizResult(
      _completion('stored').result,
      QuizSavedClassification.official,
    );
    final status = QuizRootStatus(coordinator)
      ..update(
        DailyChallengeStatus(
          date: date,
          displayDate: 'Sep 13',
          confirmedOfficialResult: official,
        ),
      );
    final confirmed = status.value;

    final practice = coordinator.complete(
      _completion('practice', intent: QuizSaveIntent.practice),
    );
    store.succeed(QuizSavedClassification.practice);
    await practice;

    expect(status.value, same(confirmed));
    expect(status.value!.confirmedOfficialResult, same(official));
  });

  test('completions before a Daily date is known leave the Hub unset', () {
    final store = _ControlledStore();
    final coordinator = QuizCompletionCoordinator(store);
    final status = QuizRootStatus(coordinator);

    coordinator.complete(_completion('early'));

    expect(status.value, isNull);
  });

  test('disposal stops listening to the coordinator', () {
    final store = _ControlledStore();
    final coordinator = QuizCompletionCoordinator(store);
    final status = QuizRootStatus(coordinator)..update(resolved);
    status.dispose();

    expect(
      () => coordinator.complete(_completion('after-dispose')),
      returnsNormally,
    );
  });
}

final class _ControlledStore implements QuizResultStore {
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

  @override
  Future<StoredQuizResult?> getBestResult(QuizBestResultKey key) async => null;
  @override
  Future<StoredQuizResult?> getOfficialDaily(QuizDate date) async => null;
  @override
  Future<bool> getQuickPlayTimingEnabled() async => true;
  @override
  Future<void> setQuickPlayTimingEnabled(bool enabled) async {}
}

QuizCompletion _completion(
  String id, {
  QuizSaveIntent intent = QuizSaveIntent.claimDailyIfAbsent,
}) {
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
    intent,
  );
}
