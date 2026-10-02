import 'package:flutter/material.dart';

import '../../../../core/navigation/source_launcher.dart';
import '../../domain/question_outcome.dart';
import 'quiz_design.dart';

/// Quick Play's explanation and sources under an answered question. Daily
/// keeps feedback compact while its total clock runs, so it shows neither.
class QuizAnswerFeedback extends StatelessWidget {
  const QuizAnswerFeedback({
    super.key,
    required this.outcome,
    required this.daily,
    required this.expired,
    required this.launcher,
  });
  final QuestionOutcome outcome;
  final bool daily, expired;
  final SourceLauncher launcher;

  static String label(QuestionOutcome outcome, bool expired) =>
      expired || outcome.kind == QuestionOutcomeKind.timedOut
      ? "Time's up"
      : outcome.kind == QuestionOutcomeKind.unanswered
      ? outcome.unansweredReason == UnansweredReason.notReached
            ? 'Not reached'
            : 'Skipped'
      : outcome.kind == QuestionOutcomeKind.correct
      ? 'Correct'
      : 'Incorrect';

  @override
  Widget build(BuildContext context) {
    if (daily) return const SizedBox.shrink();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const SizedBox(height: 8),
        Text(
          outcome.question.explanation,
          style: Theme.of(context).textTheme.bodyMedium,
        ),
        const SizedBox(height: 12),
        QuizSourcesDisclosure(
          sources: outcome.question.sources,
          launcher: launcher,
        ),
      ],
    );
  }
}

/// Compact outcome at the side of the sticky Continue action.
/// The answer is already marked on the question, so it is not repeated here.
class QuizFeedbackSummary extends StatelessWidget {
  const QuizFeedbackSummary({
    super.key,
    required this.outcome,
    required this.expired,
  });

  final QuestionOutcome outcome;
  final bool expired;

  @override
  Widget build(BuildContext context) {
    final kind = expired ? QuestionOutcomeKind.timedOut : outcome.kind;
    return Row(
      children: [
        QuizOutcomeBadge(kind: kind, size: 30),
        const SizedBox(width: 8),
        Flexible(
          child: Text(
            QuizAnswerFeedback.label(outcome, expired),
            style: Theme.of(context).textTheme.titleMedium,
          ),
        ),
      ],
    );
  }
}
