import 'quiz_answer.dart';
import 'quiz_grading.dart';
import 'quiz_question.dart';
import 'quiz_validation.dart';

enum QuestionOutcomeKind { correct, incorrect, timedOut, unanswered }

enum UnansweredReason { imageSkipped, notReached }

final class QuestionOutcome {
  QuestionOutcome._(
    this.question,
    this.kind,
    this.answer,
    this.unansweredReason,
  );
  factory QuestionOutcome.answered(QuizQuestion question, QuizAnswer answer) =>
      QuestionOutcome._(
        question,
        gradeQuizAnswer(question, answer)
            ? QuestionOutcomeKind.correct
            : QuestionOutcomeKind.incorrect,
        answer,
        null,
      );
  factory QuestionOutcome.timedOut(QuizQuestion question) =>
      QuestionOutcome._(question, QuestionOutcomeKind.timedOut, null, null);
  factory QuestionOutcome.unanswered(
    QuizQuestion question,
    UnansweredReason reason,
  ) {
    requireQuiz(
      reason != UnansweredReason.imageSkipped ||
          question is ImageIdentificationQuestion,
      'Only image questions may be skipped',
    );
    return QuestionOutcome._(
      question,
      QuestionOutcomeKind.unanswered,
      null,
      reason,
    );
  }
  final QuizQuestion question;
  final QuestionOutcomeKind kind;
  final QuizAnswer? answer;
  final UnansweredReason? unansweredReason;
  int get credit => kind == QuestionOutcomeKind.correct ? 1 : 0;
  bool get wasAnswered => answer != null;
}
