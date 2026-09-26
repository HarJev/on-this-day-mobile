import '../domain/quiz_definition.dart';
import '../domain/quiz_result.dart';
import '../domain/quiz_validation.dart';

/// Immutable handoff from setup to the future play-route owner.
final class QuizSessionLaunchRequest {
  QuizSessionLaunchRequest({
    required this.definition,
    required this.completionId,
    required this.saveIntent,
    required this.timingEnabled,
  }) {
    requireText(completionId);
    requireQuiz(
      (definition is QuickPlayQuizDefinition) ==
          (saveIntent == QuizSaveIntent.quickPlay),
      'Save intent does not match quiz mode',
    );
    requireQuiz(
      definition is! DailyQuizDefinition || timingEnabled,
      'Daily Challenge must be timed',
    );
  }

  final QuizDefinition definition;
  final String completionId;
  final QuizSaveIntent saveIntent;
  final bool timingEnabled;

  bool get isDaily => definition is DailyQuizDefinition;
}
