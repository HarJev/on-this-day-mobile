import 'quiz_question.dart';
import 'quiz_rules.dart';
import 'quiz_validation.dart';

final class QuizDate {
  QuizDate(this.isoDate) {
    requireQuiz(
      RegExp(r'^\d{4}-\d{2}-\d{2}$').hasMatch(isoDate),
      'Invalid ISO date',
    );
    final parsed = DateTime.tryParse(isoDate);
    requireQuiz(
      parsed != null && parsed.toIso8601String().substring(0, 10) == isoDate,
      'Invalid calendar date',
    );
  }
  final String isoDate;
  @override
  bool operator ==(Object other) =>
      other is QuizDate && isoDate == other.isoDate;
  @override
  int get hashCode => isoDate.hashCode;
}

final class QuizSelection {
  QuizSelection({this.collectionId, required this.displayName}) {
    if (collectionId != null) requireId(collectionId!);
    requireText(displayName);
  }
  final String? collectionId;
  final String displayName;
}

sealed class QuizDefinition {
  QuizDefinition({
    required this.questionCount,
    required List<QuizQuestion> questions,
  }) : questions = List.unmodifiable(questions) {
    requireQuiz(
      QuizRules.questionCounts.contains(questionCount) &&
          this.questions.length == questionCount &&
          this.questions.map((q) => q.id).toSet().length == questionCount,
      'Invalid quiz count or duplicate questions',
    );
  }
  final int questionCount;
  final List<QuizQuestion> questions;
}

final class DailyQuizDefinition extends QuizDefinition {
  DailyQuizDefinition({
    required super.questionCount,
    required super.questions,
    required this.challengeId,
    required this.date,
    required this.displayDate,
    required this.duration,
    this.assignmentQuestionCount = 20,
  }) {
    requireId(challengeId);
    requireText(displayDate);
    requireQuiz(
      assignmentQuestionCount == 20 && duration > Duration.zero,
      'Invalid Daily timer or assignment size',
    );
  }
  final String challengeId, displayDate;
  final QuizDate date;
  final Duration duration;
  final int assignmentQuestionCount;
}

final class QuickPlayQuizDefinition extends QuizDefinition {
  QuickPlayQuizDefinition({
    required super.questionCount,
    required super.questions,
    required this.selection,
    required Map<String, Duration> questionTimeLimits,
    required this.timingEnabledByDefault,
  }) : questionTimeLimits = Map.unmodifiable(questionTimeLimits) {
    requirePermutation(
      this.questionTimeLimits.keys.toList(),
      questions.map((q) => q.id),
    );
    requireQuiz(
      this.questionTimeLimits.values.every((d) => d > Duration.zero),
      'Nonpositive question timer',
    );
  }
  final QuizSelection selection;
  final bool timingEnabledByDefault;
  final Map<String, Duration> questionTimeLimits;
}
