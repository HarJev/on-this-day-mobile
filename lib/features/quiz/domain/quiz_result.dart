import 'question_outcome.dart';
import 'quiz_definition.dart';
import 'quiz_rules.dart';
import 'quiz_validation.dart';

enum QuizCompletionReason { questionsFinished, dailyTimeExpired }

enum QuizSaveIntent { claimDailyIfAbsent, practice, quickPlay }

enum QuizSavedClassification { official, practice, quickPlay }

final class QuizResult {
  QuizResult({
    required this.completionId,
    required this.definition,
    required this.timingEnabled,
    required this.completedAt,
    required this.reason,
    required List<QuestionOutcome> outcomes,
  }) : outcomes = List.unmodifiable(outcomes) {
    requireText(completionId);
    requireQuiz(
      this.outcomes.length == definition.questionCount,
      'Incomplete result',
    );
    for (var i = 0; i < this.outcomes.length; i++) {
      requireQuiz(
        identical(this.outcomes[i].question, definition.questions[i]),
        'Outcome must reference its frozen question in order',
      );
    }
    requireQuiz(
      definition is! DailyQuizDefinition || timingEnabled,
      'Daily must be timed',
    );
    requireQuiz(
      reason != QuizCompletionReason.dailyTimeExpired ||
          definition is DailyQuizDefinition,
      'Only Daily can expire as a session',
    );
    requireQuiz(
      timingEnabled ||
          !this.outcomes.any((o) => o.kind == QuestionOutcomeKind.timedOut),
      'Untimed result cannot time out',
    );
    final notReached = this.outcomes.indexWhere(
      (o) => o.unansweredReason == UnansweredReason.notReached,
    );
    requireQuiz(
      notReached < 0 || reason == QuizCompletionReason.dailyTimeExpired,
      'Unseen questions require Daily expiry',
    );
    if (notReached >= 0) {
      requireQuiz(
        notReached > 0,
        'A started Daily has an active or committed question',
      );
      requireQuiz(
        this.outcomes
            .skip(notReached)
            .every((o) => o.unansweredReason == UnansweredReason.notReached),
        'Unseen questions must be a suffix',
      );
    }
    if (definition is DailyQuizDefinition) {
      final timedOut = this.outcomes.indexWhere(
        (o) => o.kind == QuestionOutcomeKind.timedOut,
      );
      requireQuiz(
        this.outcomes
                .where((o) => o.kind == QuestionOutcomeKind.timedOut)
                .length <=
            1,
        'Daily has at most one active timeout',
      );
      requireQuiz(
        timedOut < 0 ||
            (reason == QuizCompletionReason.dailyTimeExpired &&
                timedOut ==
                    (notReached < 0 ? this.outcomes.length : notReached) - 1),
        'Daily timeout must precede unseen suffix',
      );
    }
  }
  final String completionId;
  final QuizDefinition definition;
  final bool timingEnabled;
  final DateTime completedAt;
  final QuizCompletionReason reason;
  final List<QuestionOutcome> outcomes;
  int get total => outcomes.length;
  int get correct => outcomes.fold(0, (sum, o) => sum + o.credit);
  int get answered => outcomes.where((o) => o.wasAnswered).length;
  int get incorrect => answered - correct;
  int get unanswered => total - answered;
  double get percentage => correct * 100 / total;
}

final class QuizCompletion {
  QuizCompletion(this.result, this.intent) {
    requireQuiz(
      (result.definition is QuickPlayQuizDefinition) ==
          (intent == QuizSaveIntent.quickPlay),
      'Save intent does not match mode',
    );
  }
  final QuizResult result;
  final QuizSaveIntent intent;
}

final class StoredQuizResult {
  StoredQuizResult(this.result, this.classification) {
    requireQuiz(
      (result.definition is QuickPlayQuizDefinition) ==
          (classification == QuizSavedClassification.quickPlay),
      'Saved classification does not match mode',
    );
  }
  final QuizResult result;
  final QuizSavedClassification classification;
}

/// Daily keys identify practice bests; official results have a separate lookup.
final class QuizBestResultKey {
  QuizBestResultKey.daily(this.date, this.questionCount)
    : collectionId = null,
      timingEnabled = true {
    requireQuiz(date != null, 'Daily key requires a date');
    _validate();
  }
  QuizBestResultKey.quickPlay({
    required this.questionCount,
    required this.timingEnabled,
    this.collectionId,
  }) : date = null {
    _validate();
  }
  void _validate() {
    requireQuiz(
      QuizRules.questionCounts.contains(questionCount),
      'Unsupported count',
    );
    if (collectionId != null) requireId(collectionId!);
  }

  final QuizDate? date;
  final String? collectionId;
  final int questionCount;
  final bool timingEnabled;
  @override
  bool operator ==(Object other) =>
      other is QuizBestResultKey &&
      date == other.date &&
      collectionId == other.collectionId &&
      questionCount == other.questionCount &&
      timingEnabled == other.timingEnabled;
  @override
  int get hashCode =>
      Object.hash(date, collectionId, questionCount, timingEnabled);
}
