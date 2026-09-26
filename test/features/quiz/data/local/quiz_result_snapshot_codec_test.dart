import 'package:flutter_test/flutter_test.dart';
import 'package:on_this_day_mobile/features/quiz/data/local/quiz_result_snapshot_codec.dart';
import 'package:on_this_day_mobile/features/quiz/domain/question_outcome.dart';
import 'package:on_this_day_mobile/features/quiz/domain/quiz_answer.dart';
import 'package:on_this_day_mobile/features/quiz/domain/quiz_definition.dart';
import 'package:on_this_day_mobile/features/quiz/domain/quiz_exceptions.dart';
import 'package:on_this_day_mobile/features/quiz/domain/quiz_question.dart';
import 'package:on_this_day_mobile/features/quiz/domain/quiz_result.dart';

import '../../support/session_fakes.dart';

void main() {
  const codec = QuizResultSnapshotCodec();

  test('round trips a Daily frozen result and keeps presentation order', () {
    final definition = sessionQuiz(daily: true) as DailyQuizDefinition;
    final result = _result(
      definition,
      completionId: 'daily-completion',
      outcomes: [
        QuestionOutcome.answered(definition.questions[0], OptionAnswer('a')),
        QuestionOutcome.answered(definition.questions[1], OptionAnswer('true')),
        QuestionOutcome.unanswered(
          definition.questions[2],
          UnansweredReason.imageSkipped,
        ),
        QuestionOutcome.answered(
          definition.questions[3],
          OrderingAnswer(['a', 'b', 'c', 'd']),
        ),
        QuestionOutcome.answered(definition.questions[4], OptionAnswer('a')),
      ],
    );

    final decoded = codec.decode(codec.encode(result));

    expect(decoded.completionId, result.completionId);
    expect(
      (decoded.definition as DailyQuizDefinition).date.isoDate,
      '2026-09-13',
    );
    expect(
      decoded.outcomes.map((outcome) => outcome.question.id),
      result.outcomes.map((outcome) => outcome.question.id),
    );
    expect((decoded.outcomes[3].answer as OrderingAnswer).orderedItemIds, [
      'a',
      'b',
      'c',
      'd',
    ]);
    expect(codec.fingerprint(decoded), codec.fingerprint(result));
  });

  test('fingerprint changes for frozen result changes', () {
    final definition = sessionQuiz();
    final correct = _result(definition, outcomes: _allCorrect(definition));
    final incorrect = _result(
      definition,
      outcomes: [
        QuestionOutcome.answered(definition.questions[0], OptionAnswer('b')),
        ..._allCorrect(definition).skip(1),
      ],
    );

    expect(codec.fingerprint(correct), isNot(codec.fingerprint(incorrect)));
  });

  test('rejects a stored outcome whose kind contradicts its answer', () {
    final definition = sessionQuiz();
    final encoded = codec.encode(
      _result(definition, outcomes: _allCorrect(definition)),
    );
    final corrupted = encoded.replaceFirst(
      '"kind":"correct"',
      '"kind":"incorrect"',
    );

    expect(
      () => codec.decode(corrupted),
      throwsA(isA<QuizStorageCorruptionException>()),
    );
  });
}

QuizResult _result(
  QuizDefinition definition, {
  String completionId = 'completion-one',
  required List<QuestionOutcome> outcomes,
}) => QuizResult(
  completionId: completionId,
  definition: definition,
  timingEnabled: true,
  completedAt: DateTime.utc(2026, 9, 13, 12),
  reason: QuizCompletionReason.questionsFinished,
  outcomes: outcomes,
);

List<QuestionOutcome> _allCorrect(QuizDefinition definition) => [
  for (final question in definition.questions)
    QuestionOutcome.answered(
      question,
      question is ChoiceQuestion
          ? OptionAnswer(question.correctOptionId)
          : OrderingAnswer(
              (question as ChronologicalOrderingQuestion).correctOrderItemIds,
            ),
    ),
];
