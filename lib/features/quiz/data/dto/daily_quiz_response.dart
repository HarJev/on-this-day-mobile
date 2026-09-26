import '../../domain/quiz_definition.dart';
import 'quiz_json.dart';
import 'quiz_question_response.dart';

final class DailyQuizResponse {
  DailyQuizResponse.fromJson(Map<String, Object?> value) {
    final json = QuizJson(value);
    json.expect('mode', 'daily');
    questionCount = json.integer('questionCount');
    assignmentQuestionCount = json.integer('assignmentQuestionCount');
    challengeId = json.string('challengeId');
    final dateJson = json.object('date');
    date = QuizDate(dateJson.string('isoDate'));
    displayDate = dateJson.string('displayDate');
    final timer = json.object('timer');
    timer.expect('mode', 'total');
    timer.prohibit('enabledByDefault');
    duration = timer.duration('durationSeconds');
    questions = List.unmodifiable(
      json
          .objects('questions')
          .map((q) => QuizQuestionResponse.fromJson(q, quickPlay: false)),
    );
  }
  late final int questionCount, assignmentQuestionCount;
  late final String challengeId, displayDate;
  late final QuizDate date;
  late final Duration duration;
  late final List<QuizQuestionResponse> questions;

  DailyQuizDefinition toDomain() => DailyQuizDefinition(
    questionCount: questionCount,
    questions: questions.map((q) => q.toDomain()).toList(),
    challengeId: challengeId,
    date: date,
    displayDate: displayDate,
    duration: duration,
    assignmentQuestionCount: assignmentQuestionCount,
  );
}
