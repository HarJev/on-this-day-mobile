import 'package:flutter_test/flutter_test.dart';
import 'package:on_this_day_mobile/features/quiz/domain/question_outcome.dart';
import 'package:on_this_day_mobile/features/quiz/domain/quiz_answer.dart';
import 'package:on_this_day_mobile/features/quiz/domain/quiz_catalog.dart';
import 'package:on_this_day_mobile/features/quiz/domain/quiz_definition.dart';
import 'package:on_this_day_mobile/features/quiz/domain/quiz_exceptions.dart';
import 'package:on_this_day_mobile/features/quiz/domain/quiz_grading.dart';
import 'package:on_this_day_mobile/features/quiz/domain/quiz_image.dart';
import 'package:on_this_day_mobile/features/quiz/domain/quiz_question.dart';
import 'package:on_this_day_mobile/features/quiz/domain/quiz_result.dart';
import 'package:on_this_day_mobile/features/quiz/domain/quiz_rules.dart';
import 'package:on_this_day_mobile/features/quiz/domain/quiz_source.dart';

final invalid = throwsA(isA<InvalidQuizDefinitionException>());
final source = QuizSource(
  displayName: 'Museum',
  url: Uri.parse('https://example.org/source'),
);
List<QuizOption> options() =>
    ['a', 'b', 'c', 'd'].map((id) => QuizOption(id, id.toUpperCase())).toList();
QuizImage image({String? creator}) => QuizImage(
  url: Uri.parse('https://example.org/image.jpg'),
  altText: 'An archival object',
  source: 'Museum',
  sourceUrl: source.url,
  attribution: 'Museum collection',
  creator: creator,
  license: 'CC0',
  licenseUrl: Uri.parse('https://example.org/license'),
);
MultipleChoiceQuestion choice({
  String id = 'question',
  List<QuizOption>? choices,
  String correct = 'a',
}) => MultipleChoiceQuestion(
  id: id,
  difficulty: QuizDifficulty.easy,
  prompt: 'Which one?',
  explanation: 'An explanation.',
  sources: [source],
  options: choices ?? options(),
  correctOptionId: correct,
);
TrueFalseQuestion truth({List<QuizOption>? choices}) => TrueFalseQuestion(
  id: 'truth',
  difficulty: QuizDifficulty.medium,
  prompt: 'Is this true?',
  explanation: 'An explanation.',
  sources: [source],
  options:
      choices ?? [QuizOption('true', 'True'), QuizOption('false', 'False')],
  correctOptionId: 'true',
);
ImageIdentificationQuestion visual() => ImageIdentificationQuestion(
  id: 'visual',
  difficulty: QuizDifficulty.hard,
  prompt: 'Identify this object.',
  explanation: 'An explanation.',
  sources: [source],
  options: options(),
  correctOptionId: 'a',
  image: image(),
);
ChronologicalOrderingQuestion order({List<String>? correct}) =>
    ChronologicalOrderingQuestion(
      id: 'order',
      difficulty: QuizDifficulty.hard,
      prompt: 'Order these.',
      explanation: 'An explanation.',
      sources: [source],
      items: [
        'd',
        'b',
        'a',
        'c',
      ].map((id) => QuizOrderingItem(id, id)).toList(),
      correctOrderItemIds: correct ?? ['a', 'b', 'c', 'd'],
    );
List<QuizQuestion> questions() => [
  choice(),
  truth(),
  visual(),
  order(),
  choice(id: 'last'),
];
DailyQuizDefinition daily({Duration duration = const Duration(seconds: 120)}) =>
    DailyQuizDefinition(
      questionCount: 5,
      questions: questions(),
      challengeId: 'daily-2026-08-24',
      date: QuizDate('2026-08-24'),
      displayDate: 'Aug 24',
      duration: duration,
    );
QuickPlayQuizDefinition quick({Map<String, Duration>? limits}) {
  final qs = questions();
  return QuickPlayQuizDefinition(
    questionCount: 5,
    questions: qs,
    selection: QuizSelection(displayName: 'Mixed'),
    questionTimeLimits:
        limits ?? {for (final q in qs) q.id: const Duration(seconds: 7)},
    timingEnabledByDefault: true,
  );
}

QuestionOutcome correctOutcome(QuizQuestion q) => QuestionOutcome.answered(
  q,
  q is ChoiceQuestion
      ? OptionAnswer(q.correctOptionId)
      : OrderingAnswer(
          (q as ChronologicalOrderingQuestion).correctOrderItemIds,
        ),
);
QuizResult result(
  QuizDefinition quiz,
  List<QuestionOutcome> outcomes, {
  bool timed = true,
  QuizCompletionReason reason = QuizCompletionReason.questionsFinished,
}) => QuizResult(
  completionId: 'completion-1',
  definition: quiz,
  timingEnabled: timed,
  completedAt: DateTime.utc(2026, 8, 24),
  reason: reason,
  outcomes: outcomes,
);

void main() {
  test('sources are required and cannot be duplicated', () {
    for (final sources in <List<QuizSource>>[
      [],
      [source, source],
    ]) {
      expect(
        () => MultipleChoiceQuestion(
          id: 'source-test',
          difficulty: QuizDifficulty.easy,
          prompt: 'Prompt',
          explanation: 'Explanation',
          sources: sources,
          options: options(),
          correctOptionId: 'a',
        ),
        invalid,
      );
    }
  });
  test('definition rejects short or duplicate question lists', () {
    for (final qs in [
      questions().take(4).toList(),
      List<QuizQuestion>.filled(5, choice()),
    ]) {
      expect(
        () => DailyQuizDefinition(
          questionCount: 5,
          questions: qs,
          challengeId: 'daily-test',
          date: QuizDate('2026-08-24'),
          displayDate: 'Aug 24',
          duration: const Duration(seconds: 10),
        ),
        invalid,
      );
    }
    expect(() => daily().questions.clear(), throwsUnsupportedError);
  });
  test(
    'Daily expiry cannot contain only unseen questions or later answers',
    () {
      final d = daily();
      final unseen = d.questions
          .map(
            (q) => QuestionOutcome.unanswered(q, UnansweredReason.notReached),
          )
          .toList();
      expect(
        () => result(d, unseen, reason: QuizCompletionReason.dailyTimeExpired),
        invalid,
      );
      unseen[0] = QuestionOutcome.timedOut(d.questions[0]);
      expect(
        result(
          d,
          unseen,
          reason: QuizCompletionReason.dailyTimeExpired,
        ).unanswered,
        5,
      );
      unseen[2] = correctOutcome(d.questions[2]);
      expect(
        () => result(d, unseen, reason: QuizCompletionReason.dailyTimeExpired),
        invalid,
      );
    },
  );
  test('Daily final active timeout completes without an unseen suffix', () {
    final d = daily();
    final outcomes = d.questions.map(correctOutcome).toList();
    outcomes[4] = QuestionOutcome.timedOut(d.questions[4]);
    expect(
      result(
        d,
        outcomes,
        reason: QuizCompletionReason.dailyTimeExpired,
      ).correct,
      4,
    );
    expect(() => result(d, outcomes), invalid);
    outcomes[0] = QuestionOutcome.timedOut(d.questions[0]);
    expect(
      () => result(d, outcomes, reason: QuizCompletionReason.dailyTimeExpired),
      invalid,
    );
  });
  test('save intents distinguish Daily claim/practice from Quick Play', () {
    final d = daily();
    final r = result(d, d.questions.map(correctOutcome).toList());
    expect(
      QuizCompletion(r, QuizSaveIntent.practice).intent,
      QuizSaveIntent.practice,
    );
    expect(() => QuizCompletion(r, QuizSaveIntent.quickPlay), invalid);
    final q = quick();
    expect(
      () => QuizCompletion(
        result(q, q.questions.map(correctOutcome).toList()),
        QuizSaveIntent.claimDailyIfAbsent,
      ),
      invalid,
    );
  });
  for (final q in [choice(), truth(), visual()]) {
    test('${q.type} grades IDs, not display position', () {
      expect(gradeQuizAnswer(q, OptionAnswer(q.correctOptionId)), isTrue);
      expect(gradeQuizAnswer(q, OptionAnswer(q.options.last.id)), isFalse);
      expect(() => gradeQuizAnswer(q, OptionAnswer('missing')), invalid);
      expect(
        () => gradeQuizAnswer(q, OrderingAnswer(['a', 'b', 'c', 'd'])),
        invalid,
      );
    });
  }
  test('ordering is exact with no partial credit', () {
    final q = order();
    expect(gradeQuizAnswer(q, OrderingAnswer(['a', 'b', 'c', 'd'])), isTrue);
    expect(
      QuestionOutcome.answered(q, OrderingAnswer(['b', 'a', 'c', 'd'])).credit,
      0,
    );
    expect(
      () => gradeQuizAnswer(q, OrderingAnswer(['a', 'b', 'c', 'unknown'])),
      invalid,
    );
    expect(() => gradeQuizAnswer(q, OptionAnswer('a')), invalid);
    expect(q.items.map((i) => i.id), ['d', 'b', 'a', 'c']);
  });
  for (final ids in [
    ['a', 'a', 'c', 'd'],
    ['a', 'b', 'c'],
    ['a', 'b', 'c', 'unknown'],
  ]) {
    test(
      'rejects malformed canonical permutation $ids',
      () => expect(() => order(correct: ids), invalid),
    );
  }
  test('question cardinalities and IDs are enforced at runtime', () {
    expect(() => choice(id: 'Bad ID'), invalid);
    expect(() => choice(choices: options().take(3).toList()), invalid);
    expect(
      () => choice(choices: [QuizOption('a', 'A'), ...options().take(3)]),
      invalid,
    );
    expect(() => choice(correct: 'missing'), invalid);
    expect(
      () => truth(
        choices: [QuizOption('false', 'False'), QuizOption('true', 'True')],
      ),
      invalid,
    );
    expect(() => QuizOption('a', '  '), invalid);
    expect(() => OrderingAnswer(['a', 'a', 'b', 'c']), invalid);
  });
  test('provenance validates URLs and optional creator', () {
    expect(image().creator, isNull);
    expect(image(creator: 'Artist').creator, 'Artist');
    expect(() => image(creator: ' '), invalid);
    expect(
      () =>
          QuizSource(displayName: 'Name', url: Uri.parse('http://example.org')),
      invalid,
    );
    expect(() => QuizSource(displayName: ' ', url: source.url), invalid);
  });
  test('questions and answers defensively copy lists', () {
    final supplied = options();
    final q = choice(choices: supplied);
    supplied.clear();
    expect(q.options.length, 4);
    expect(() => q.options.clear(), throwsUnsupportedError);
    expect(() => q.sources.clear(), throwsUnsupportedError);
    final ids = ['a', 'b', 'c', 'd'];
    final answer = OrderingAnswer(ids);
    ids.clear();
    expect(answer.orderedItemIds, ['a', 'b', 'c', 'd']);
    expect(() => answer.orderedItemIds.clear(), throwsUnsupportedError);
    expect(() => order().correctOrderItemIds.clear(), throwsUnsupportedError);
  });
  test('positive backend timers override present defaults', () {
    expect(daily(duration: const Duration(seconds: 17)).duration.inSeconds, 17);
    expect(quick().questionTimeLimits.values.first.inSeconds, 7);
    expect(() => daily(duration: Duration.zero), invalid);
    expect(() => quick(limits: {}), invalid);
    expect(
      () => quick(limits: {for (final q in questions()) q.id: Duration.zero}),
      invalid,
    );
    expect(() => quick().questionTimeLimits.clear(), throwsUnsupportedError);
    expect(QuizRules.dailyDefaults.map((k, v) => MapEntry(k, v.inSeconds)), {
      5: 120,
      10: 240,
      20: 480,
    });
    expect(QuizRules.quickPlayDefaults.values.map((d) => d.inSeconds), [
      20,
      20,
      30,
      45,
    ]);
  });
  test('dates reject normalization and compare by value', () {
    expect(() => QuizDate('2026-02-30'), invalid);
    expect(() => QuizDate('2026-2-01'), invalid);
    expect(QuizDate('2024-02-29'), QuizDate('2024-02-29'));
  });
  test('catalog validates availability and timer coverage', () {
    final available = QuizAvailability(
      publishedQuestionCount: 12,
      supportedQuestionCounts: [5, 10],
    );
    final catalog = QuizCatalog(
      mixed: available,
      collections: [],
      quickPlayTimerDefaults: QuizRules.quickPlayDefaults,
    );
    expect(() => catalog.collections.clear(), throwsUnsupportedError);
    expect(
      () => catalog.quickPlayTimerDefaults.clear(),
      throwsUnsupportedError,
    );
    expect(
      () => QuizAvailability(
        publishedQuestionCount: 12,
        supportedQuestionCounts: [5, 10, 20],
      ),
      invalid,
    );
    expect(
      () => QuizCatalog(
        mixed: available,
        collections: [],
        quickPlayTimerDefaults: {},
      ),
      invalid,
    );
  });
  test('finished result derives counts without stored classification', () {
    final q = quick();
    final outcomes = q.questions.map(correctOutcome).toList();
    outcomes[0] = QuestionOutcome.answered(q.questions[0], OptionAnswer('b'));
    outcomes[2] = QuestionOutcome.unanswered(
      q.questions[2],
      UnansweredReason.imageSkipped,
    );
    final r = result(q, outcomes, timed: false);
    outcomes.clear();
    expect(
      [r.total, r.correct, r.incorrect, r.answered, r.unanswered, r.percentage],
      [5, 3, 1, 4, 1, 60],
    );
    expect(() => r.outcomes.clear(), throwsUnsupportedError);
    expect(
      StoredQuizResult(r, QuizSavedClassification.quickPlay).result,
      same(r),
    );
    expect(
      () => StoredQuizResult(r, QuizSavedClassification.official),
      invalid,
    );
  });
  test('Daily answering expiry marks active timeout and unseen suffix', () {
    final q = daily();
    final outcomes = [
      correctOutcome(q.questions[0]),
      QuestionOutcome.timedOut(q.questions[1]),
      ...q.questions
          .skip(2)
          .map(
            (v) => QuestionOutcome.unanswered(v, UnansweredReason.notReached),
          ),
    ];
    final r = result(
      q,
      outcomes,
      reason: QuizCompletionReason.dailyTimeExpired,
    );
    expect(r.correct, 1);
    expect(r.unanswered, 4);
    expect(
      QuizCompletion(r, QuizSaveIntent.claimDailyIfAbsent).result,
      same(r),
    );
    expect(
      StoredQuizResult(r, QuizSavedClassification.practice).result,
      same(r),
    );
  });
  test('Daily feedback expiry preserves committed answer', () {
    final q = daily();
    final r = result(q, [
      correctOutcome(q.questions[0]),
      ...q.questions
          .skip(1)
          .map(
            (v) => QuestionOutcome.unanswered(v, UnansweredReason.notReached),
          ),
    ], reason: QuizCompletionReason.dailyTimeExpired);
    expect(r.outcomes.first.kind, QuestionOutcomeKind.correct);
    expect(
      r.outcomes.where((o) => o.kind == QuestionOutcomeKind.timedOut),
      isEmpty,
    );
  });
  test('rejects invalid result counts, order and timeout modes', () {
    final q = quick();
    final outcomes = q.questions.map(correctOutcome).toList();
    expect(() => result(q, []), invalid);
    expect(() => result(q, outcomes.reversed.toList()), invalid);
    outcomes[0] = QuestionOutcome.timedOut(q.questions[0]);
    expect(() => result(q, outcomes, timed: false), invalid);
    expect(result(q, outcomes).unanswered, 1);
    expect(
      () => result(q, outcomes, reason: QuizCompletionReason.dailyTimeExpired),
      invalid,
    );
    expect(
      () => QuestionOutcome.unanswered(
        q.questions[0],
        UnansweredReason.imageSkipped,
      ),
      invalid,
    );
    final d = daily();
    expect(
      () => result(d, d.questions.map(correctOutcome).toList(), timed: false),
      invalid,
    );
  });
  test('best keys use date/count or selection/count/timing', () {
    expect(
      QuizBestResultKey.daily(QuizDate('2026-08-24'), 5),
      QuizBestResultKey.daily(QuizDate('2026-08-24'), 5),
    );
    expect(
      QuizBestResultKey.quickPlay(questionCount: 5, timingEnabled: true),
      isNot(
        QuizBestResultKey.quickPlay(questionCount: 5, timingEnabled: false),
      ),
    );
  });
}
