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
  QuizFeedback({
    required this.index,
    required this.outcome,
    required this.remaining,
    List<String>? orderingDraft,
  }) : orderingDraft = orderingDraft == null
           ? null
           : List.unmodifiable(orderingDraft);
  final int index;
  final QuestionOutcome outcome;
  final Duration? remaining;

  /// Presentation-only context for a chronological question. It is never an
  /// answer and is deliberately excluded from [QuizResult].
  final List<String>? orderingDraft;
}

enum QuizCompletionDelivery { pending, delivered, failed }

final class QuizCompleted extends QuizSessionState {
  QuizCompleted(
    this.result,
    this.delivery, {
    this.deliveryError,
    List<String>? orderingDraft,
  }) : orderingDraft = orderingDraft == null
           ? null
           : List.unmodifiable(orderingDraft);
  final QuizResult result;
  final QuizCompletionDelivery delivery;
  final Object? deliveryError;

  /// Presentation-only final-question context; not part of the frozen result.
  final List<String>? orderingDraft;
}

final class QuizAbandoned extends QuizSessionState {
  const QuizAbandoned();
}

final class QuizInterrupted extends QuizSessionState {
  const QuizInterrupted(this.cause);
  final Object cause;
}
