import 'package:flutter/material.dart';

import '../../../../core/config/app_colors.dart';
import '../../../../core/navigation/source_launcher.dart';
import '../../domain/question_outcome.dart';
import '../../domain/quiz_answer.dart';
import '../../domain/quiz_question.dart';
import 'quiz_answer_feedback.dart';
import 'quiz_source_row.dart';

class QuizOrderingFeedback extends StatelessWidget {
  const QuizOrderingFeedback({
    super.key,
    required this.outcome,
    required this.daily,
    required this.expired,
    required this.orderingDraft,
    required this.launcher,
  });

  final QuestionOutcome outcome;
  final bool daily, expired;
  final List<String>? orderingDraft;
  final SourceLauncher launcher;

  ChronologicalOrderingQuestion get question =>
      outcome.question as ChronologicalOrderingQuestion;

  @override
  Widget build(BuildContext context) {
    final submitted = outcome.answer is OrderingAnswer
        ? (outcome.answer as OrderingAnswer).orderedItemIds
        : null;
    final draft = outcome.kind == QuestionOutcomeKind.timedOut
        ? orderingDraft
        : null;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const Divider(),
        Text(
          QuizAnswerFeedback.label(outcome, expired),
          style: Theme.of(context).textTheme.titleMedium,
        ),
        if (submitted != null) ...[
          const SizedBox(height: 12),
          _OrderList(
            label: 'Your submitted order',
            ids: submitted,
            question: question,
          ),
        ],
        if (draft != null) ...[
          const SizedBox(height: 12),
          _OrderList(
            label: 'Your draft - not submitted',
            ids: draft,
            question: question,
          ),
        ],
        const SizedBox(height: 12),
        _OrderList(
          label: 'Correct order',
          ids: question.correctOrderItemIds,
          question: question,
        ),
        if (!daily) ...[
          const SizedBox(height: 16),
          Text(question.explanation),
          const SizedBox(height: 8),
          for (final source in question.sources)
            QuizSourceRow(
              key: ValueKey('${question.id}:${source.url}'),
              source: source,
              launcher: launcher,
            ),
        ],
      ],
    );
  }
}

class _OrderList extends StatelessWidget {
  const _OrderList({
    required this.label,
    required this.ids,
    required this.question,
  });

  final String label;
  final List<String> ids;
  final ChronologicalOrderingQuestion question;

  @override
  Widget build(BuildContext context) => Semantics(
    container: true,
    label: label,
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          label,
          style: const TextStyle(
            color: AppColors.mutedGray,
            fontWeight: FontWeight.w600,
          ),
        ),
        const SizedBox(height: 4),
        for (var i = 0; i < ids.length; i++)
          Padding(
            padding: const EdgeInsets.only(bottom: 4),
            child: Text(
              '${i + 1}. ${question.items.firstWhere((item) => item.id == ids[i]).text}',
            ),
          ),
      ],
    ),
  );
}
