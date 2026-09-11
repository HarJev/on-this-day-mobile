import 'quiz_rules.dart';
import 'quiz_validation.dart';

final class QuizAvailability {
  QuizAvailability({
    required this.publishedQuestionCount,
    required List<int> supportedQuestionCounts,
  }) : supportedQuestionCounts = List.unmodifiable(supportedQuestionCounts) {
    requireQuiz(publishedQuestionCount >= 0, 'Negative published count');
    final expected = QuizRules.questionCounts
        .where((n) => n <= publishedQuestionCount)
        .toList();
    requireQuiz(
      this.supportedQuestionCounts.length == expected.length &&
          this.supportedQuestionCounts.toSet().length == expected.length &&
          this.supportedQuestionCounts.toSet().containsAll(expected),
      'Inconsistent supported counts',
    );
  }
  final int publishedQuestionCount;
  final List<int> supportedQuestionCounts;
}

final class QuizCollection {
  QuizCollection({
    required this.id,
    required this.name,
    required this.group,
    required this.availability,
  }) {
    requireId(id);
    requireText(name);
  }
  final String id, name;
  final QuizCollectionGroup group;
  final QuizAvailability availability;
}

final class QuizCatalog {
  QuizCatalog({
    required this.mixed,
    required List<QuizCollection> collections,
    required Map<QuizQuestionType, Duration> quickPlayTimerDefaults,
  }) : collections = List.unmodifiable(collections),
       quickPlayTimerDefaults = Map.unmodifiable(quickPlayTimerDefaults) {
    requireQuiz(
      this.collections.map((c) => c.id).toSet().length ==
          this.collections.length,
      'Duplicate collection IDs',
    );
    requireQuiz(
      this.quickPlayTimerDefaults.length == QuizQuestionType.values.length &&
          QuizQuestionType.values.every(
            (t) =>
                (this.quickPlayTimerDefaults[t] ?? Duration.zero) >
                Duration.zero,
          ),
      'Incomplete or invalid timer defaults',
    );
  }
  final QuizAvailability mixed;
  final List<QuizCollection> collections;
  final Map<QuizQuestionType, Duration> quickPlayTimerDefaults;
}
