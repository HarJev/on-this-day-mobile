import '../domain/question_outcome.dart';
import '../domain/quiz_question.dart';
import '../domain/quiz_result.dart';

sealed class QuizSessionState {
  const QuizSessionState();
}

final class QuizPreparing extends QuizSessionState {
  const QuizPreparing();
}

final class QuizPreparationFailed extends QuizSessionState {
  const QuizPreparationFailed(this.cause);
  final Object cause;
}

final class QuizReady extends QuizSessionState {
  const QuizReady();
}

final class QuizAnswering extends QuizSessionState {
  QuizAnswering({
    required this.index,
    required this.question,
    required this.remaining,
    required List<String> orderingDraft,
  }) : orderingDraft = List.unmodifiable(orderingDraft);
  final int index;
  final QuizQuestion question;
  final Duration? remaining;
  final List<String> orderingDraft;
}

final class QuizFeedback extends QuizSessionState {
  const QuizFeedback({
    required this.index,
    required this.outcome,
    required this.remaining,
  });
  final int index;
  final QuestionOutcome outcome;
  final Duration? remaining;
}

enum QuizCompletionDelivery { pending, delivered, failed }

final class QuizCompleted extends QuizSessionState {
  const QuizCompleted(this.result, this.delivery, {this.deliveryError});
  final QuizResult result;
  final QuizCompletionDelivery delivery;
  final Object? deliveryError;
}

final class QuizAbandoned extends QuizSessionState {
  const QuizAbandoned();
}

final class QuizInterrupted extends QuizSessionState {
  const QuizInterrupted(this.cause);
  final Object cause;
}
