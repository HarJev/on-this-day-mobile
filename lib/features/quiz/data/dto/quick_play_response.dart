import '../../domain/quiz_definition.dart';
import 'quiz_json.dart';
import 'quiz_question_response.dart';

final class QuickPlayResponse {
  QuickPlayResponse.fromJson(Map<String, Object?> value) {
    final json = QuizJson(value);
    json.expect('mode', 'quick_play');
    questionCount = json.integer('questionCount');
    final selected = json.object('selection');
    if (!selected.value.containsKey('collectionId')) {
      selected.invalid('collectionId', 'string or explicit null for Mixed');
    }
    selection = QuizSelection(
      collectionId: selected.nullableString('collectionId'),
      displayName: selected.string('displayName'),
    );
    final timer = json.object('timer');
    timer.expect('mode', 'per_question');
    timer.prohibit('durationSeconds');
    enabledByDefault = timer.boolean('enabledByDefault');
    questions = List.unmodifiable(
      json
          .objects('questions')
          .map((q) => QuizQuestionResponse.fromJson(q, quickPlay: true)),
    );
  }
  late final int questionCount;
  late final QuizSelection selection;
  late final bool enabledByDefault;
  late final List<QuizQuestionResponse> questions;

  QuickPlayQuizDefinition toDomain() => QuickPlayQuizDefinition(
    questionCount: questionCount,
    selection: selection,
    timingEnabledByDefault: enabledByDefault,
    questions: questions.map((q) => q.toDomain()).toList(),
    questionTimeLimits: {for (final q in questions) q.id: q.timeLimit!},
  );
}
