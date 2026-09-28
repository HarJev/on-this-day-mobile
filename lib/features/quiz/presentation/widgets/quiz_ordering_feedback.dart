import 'package:flutter/material.dart';

import '../../../../core/config/app_colors.dart';
import '../../../../core/config/app_theme.dart';
import '../../../../core/navigation/source_launcher.dart';
import '../../domain/question_outcome.dart';
import '../../domain/quiz_answer.dart';
import '../../domain/quiz_question.dart';
import 'quiz_design.dart';
import 'quiz_ordering_question.dart';

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
        const SizedBox(height: 14),
        if (submitted != null)
          _MarkedTimeline(
            label: 'Your submitted order',
            ids: submitted,
            question: question,
          ),
        if (draft != null)
          _OrderList(
            label: 'Your draft - not submitted',
            ids: draft,
            question: question,
          ),
        const SizedBox(height: 12),
        _OrderList(
          label: 'Correct order',
          ids: question.correctOrderItemIds,
          question: question,
        ),
        if (!daily) ...[
          const SizedBox(height: 16),
          Text(
            question.explanation,
            style: Theme.of(context).textTheme.bodyMedium,
          ),
          const SizedBox(height: 12),
          QuizSourcesDisclosure(sources: question.sources, launcher: launcher),
        ],
      ],
    );
  }
}

/// The submitted order on the timeline, each row marked in place or with
/// the position it belongs in.
class _MarkedTimeline extends StatelessWidget {
  const _MarkedTimeline({
    required this.label,
    required this.ids,
    required this.question,
  });

  final String label;
  final List<String> ids;
  final ChronologicalOrderingQuestion question;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    return Semantics(
      container: true,
      label: label,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            label,
            style: AppText.tag.copyWith(
              fontSize: 13,
              color: AppColors.mutedGray,
            ),
          ),
          const SizedBox(height: 8),
          for (var i = 0; i < ids.length; i++)
            Builder(
              builder: (context) {
                final item = question.items.firstWhere((x) => x.id == ids[i]);
                final belongs = question.correctOrderItemIds.indexOf(ids[i]);
                final inPlace = belongs == i;
                final status = inPlace
                    ? 'In place'
                    : 'Belongs ${quizOrdinal(belongs + 1)}';
                return QuizTimelineRow(
                  index: i,
                  count: ids.length,
                  node: QuizTimelineNode(inPlace: inPlace),
                  child: Semantics(
                    label: '${i + 1}. ${item.text}, $status',
                    excludeSemantics: true,
                    child: Container(
                      constraints: const BoxConstraints(minHeight: 56),
                      padding: const EdgeInsets.all(13.5),
                      decoration: BoxDecoration(
                        color: inPlace
                            ? AppColors.cobaltTint
                            : AppColors.softIvory,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                          color: inPlace
                              ? AppColors.archivalCobalt
                              : AppColors.mutedCopper,
                          width: 1.5,
                        ),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            status,
                            style: AppText.tag.copyWith(
                              color: inPlace
                                  ? AppColors.archivalCobalt
                                  : AppColors.copperDark,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            item.text,
                            style: textTheme.bodyMedium?.copyWith(height: 1.35),
                          ),
                        ],
                      ),
                    ),
                  ),
                );
              },
            ),
        ],
      ),
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
          style: AppText.tag.copyWith(fontSize: 13, color: AppColors.mutedGray),
        ),
        const SizedBox(height: 6),
        for (var i = 0; i < ids.length; i++)
          Padding(
            padding: const EdgeInsets.only(bottom: 4),
            child: Text(
              '${i + 1}. ${question.items.firstWhere((item) => item.id == ids[i]).text}',
              style: Theme.of(context).textTheme.bodyMedium,
            ),
          ),
      ],
    ),
  );
}
