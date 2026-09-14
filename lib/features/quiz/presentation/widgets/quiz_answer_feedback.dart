import 'package:flutter/material.dart';
import '../../../../core/navigation/source_launcher.dart';
import '../../domain/question_outcome.dart';
import 'quiz_source_row.dart';

class QuizAnswerFeedback extends StatelessWidget {
  const QuizAnswerFeedback({
    super.key,
    required this.outcome,
    required this.daily,
    required this.expired,
    required this.launcher,
    this.showLabel = true,
  });
  final QuestionOutcome outcome;
  final bool daily, expired;
  final bool showLabel;
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
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.stretch,
    children: [
      if (showLabel || !daily) const Divider(),
      if (showLabel)
        Text(
          label(outcome, expired),
          style: Theme.of(context).textTheme.titleMedium,
        ),
      if (!daily) ...[
        const SizedBox(height: 10),
        Text(outcome.question.explanation),
        const SizedBox(height: 8),
        for (final source in outcome.question.sources)
          QuizSourceRow(
            key: ValueKey('${outcome.question.id}:${source.url}'),
            source: source,
            launcher: launcher,
          ),
      ],
    ],
  );
}
