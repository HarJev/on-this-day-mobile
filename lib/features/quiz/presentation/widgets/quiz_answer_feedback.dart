import 'package:flutter/material.dart';

import '../../../../core/config/app_colors.dart';
import '../../../../core/config/app_theme.dart';
import '../../../../core/navigation/source_launcher.dart';
import '../../domain/question_outcome.dart';
import '../../domain/quiz_answer.dart';
import '../../domain/quiz_question.dart';
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

/// The outcome at the top of the sticky footer: a marked circle, the result
/// in words, and the correct answer or placement in one quiet line.
class QuizFeedbackSummary extends StatelessWidget {
  const QuizFeedbackSummary({
    super.key,
    required this.outcome,
    required this.expired,
  });

  final QuestionOutcome outcome;
  final bool expired;

  static String? detailFor(QuestionOutcome outcome, bool expired) {
    final question = outcome.question;
    if (expired || outcome.kind == QuestionOutcomeKind.timedOut) {
      return 'No answer recorded';
    }
    if (question is ChronologicalOrderingQuestion) {
      final answer = outcome.answer;
      if (answer is! OrderingAnswer) return null;
      var inPlace = 0;
      for (var i = 0; i < answer.orderedItemIds.length; i++) {
        if (answer.orderedItemIds[i] == question.correctOrderItemIds[i]) {
          inPlace++;
        }
      }
      return '$inPlace of ${question.items.length} in place';
    }
    if (question is ChoiceQuestion &&
        outcome.kind != QuestionOutcomeKind.correct) {
      final correct = question.options.firstWhere(
        (option) => option.id == question.correctOptionId,
      );
      return 'Answer: ${correct.text}';
    }
    return null;
  }

  @override
  Widget build(BuildContext context) {
    final kind = expired ? QuestionOutcomeKind.timedOut : outcome.kind;
    final detail = detailFor(outcome, expired);
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        children: [
          QuizOutcomeBadge(kind: kind),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  QuizAnswerFeedback.label(outcome, expired),
                  style: AppText.sectionHeader,
                ),
                if (detail != null)
                  Text(
                    detail,
                    style: Theme.of(
                      context,
                    ).textTheme.bodySmall?.copyWith(color: AppColors.mutedGray),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
