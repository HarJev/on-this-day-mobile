import 'package:flutter/material.dart';

import '../../../core/config/app_colors.dart';
import '../../../core/config/app_theme.dart';
import '../../../core/images/cached_optional_image_loader.dart';
import '../../../core/navigation/source_launcher.dart';
import '../domain/question_outcome.dart';
import '../domain/quiz_answer.dart';
import '../domain/quiz_definition.dart';
import '../domain/quiz_image.dart';
import '../domain/quiz_question.dart';
import '../domain/quiz_result.dart';
import 'widgets/quiz_design.dart';
import 'widgets/quiz_related_history.dart';
import 'widgets/quiz_review_external_link.dart';
import 'widgets/quiz_review_image.dart';

/// Pure presentation of a frozen result. It has no persistence, coordinator,
/// repository, or grading dependency and also works with decoded snapshots.
final class QuizFullReviewScreen extends StatelessWidget {
  const QuizFullReviewScreen({
    super.key,
    required this.result,
    required this.sourceLauncher,
    this.onOpenEvent,
    required this.onDone,
    this.imageLoader,
  });

  final QuizResult result;
  final SourceLauncher sourceLauncher;
  final ValueChanged<String>? onOpenEvent;
  final VoidCallback onDone;

  /// Loads picture-question images through the shared cache. Without one,
  /// Review shows the unavailable message.
  final OptionalImageLoader? imageLoader;

  @override
  Widget build(BuildContext context) {
    final definition = result.definition;
    final context_ = switch (definition) {
      DailyQuizDefinition(:final displayDate) =>
        'Daily Challenge · $displayDate',
      QuickPlayQuizDefinition(:final selection) =>
        'Quick Play · ${selection.displayName}',
    };
    final textTheme = Theme.of(context).textTheme;
    return Scaffold(
      appBar: AppBar(title: const Text('Full review')),
      body: ListView.separated(
        key: const PageStorageKey('quiz-review-scroll'),
        padding: const EdgeInsets.fromLTRB(20, 4, 20, 32),
        itemCount: result.outcomes.length + 2,
        itemBuilder: (context, index) {
          if (index == 0) {
            return Row(
              children: [
                Expanded(
                  child: Text(
                    context_,
                    style: textTheme.bodyMedium?.copyWith(
                      color: AppColors.mutedGray,
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Text(
                  '${result.correct} of ${result.total}',
                  style: textTheme.labelLarge,
                ),
              ],
            );
          }
          if (index == result.outcomes.length + 1) {
            return FilledButton(onPressed: onDone, child: const Text('Done'));
          }
          final outcome = result.outcomes[index - 1];
          return _ReviewQuestion(
            key: ValueKey('review-${outcome.question.id}'),
            number: index,
            outcome: outcome,
            sourceLauncher: sourceLauncher,
            onOpenEvent: onOpenEvent,
            imageLoader: imageLoader,
          );
        },
        separatorBuilder: (_, _) =>
            const Divider(height: 24, color: AppColors.hairline),
      ),
    );
  }
}

class _ReviewQuestion extends StatelessWidget {
  const _ReviewQuestion({
    super.key,
    required this.number,
    required this.outcome,
    required this.sourceLauncher,
    this.onOpenEvent,
    this.imageLoader,
  });

  final int number;
  final QuestionOutcome outcome;
  final SourceLauncher sourceLauncher;
  final ValueChanged<String>? onOpenEvent;
  final OptionalImageLoader? imageLoader;

  QuizQuestion get question => outcome.question;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    final (typeIcon, typeLabel) = QuizTypeLabel.of(question.type);
    return Semantics(
      container: true,
      label: 'Question $number: ${quizOutcomeText(outcome)}',
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 8),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Wrap(
              spacing: 10,
              runSpacing: 6,
              crossAxisAlignment: WrapCrossAlignment.center,
              children: [
                Text('Question $number', style: textTheme.labelMedium),
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(typeIcon, size: 16, color: AppColors.mutedCopper),
                    const SizedBox(width: 6),
                    Flexible(
                      child: Text(typeLabel, style: textTheme.bodySmall),
                    ),
                  ],
                ),
                _ReviewStatus(outcome: outcome),
              ],
            ),
            const SizedBox(height: 10),
            Semantics(
              header: true,
              child: Text(
                question.prompt,
                style: AppText.questionPromptAnswered,
              ),
            ),
            const SizedBox(height: 12),
            _AnswerReview(outcome: outcome),
            const SizedBox(height: 12),
            Text(question.explanation, style: textTheme.bodyMedium),
            if (question.relatedEvents.isNotEmpty && onOpenEvent != null)
              QuizRelatedHistory(
                key: ValueKey('${question.id}:related-history'),
                events: question.relatedEvents,
                onOpenEvent: onOpenEvent!,
              ),
            const SizedBox(height: 12),
            if (question case ImageIdentificationQuestion(:final image))
              QuizReviewImage(
                key: ValueKey('${question.id}:review-image'),
                image: image,
                loader: imageLoader,
              ),
            if (question is ImageIdentificationQuestion)
              QuizDisclosure(
                key: ValueKey('${question.id}:image-credit'),
                icon: Icons.photo_camera_outlined,
                label: 'Image credit',
                child: _ImageProvenance(
                  image: (question as ImageIdentificationQuestion).image,
                  launcher: sourceLauncher,
                  questionId: question.id,
                ),
              ),
            QuizSourcesDisclosure(
              key: ValueKey('${question.id}:sources'),
              sources: question.sources,
              launcher: sourceLauncher,
              inline: true,
            ),
            const SizedBox(height: 8),
          ],
        ),
      ),
    );
  }
}

class _ReviewStatus extends StatelessWidget {
  const _ReviewStatus({required this.outcome});

  final QuestionOutcome outcome;

  @override
  Widget build(BuildContext context) {
    final correct = outcome.kind == QuestionOutcomeKind.correct;
    final color = correct ? AppColors.archivalCobalt : AppColors.copperDark;
    final icon = switch (outcome.kind) {
      QuestionOutcomeKind.correct => Icons.check,
      QuestionOutcomeKind.incorrect => Icons.close,
      QuestionOutcomeKind.timedOut => Icons.hourglass_bottom,
      QuestionOutcomeKind.unanswered => Icons.remove,
    };
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        ExcludeSemantics(child: Icon(icon, size: 16, color: color)),
        const SizedBox(width: 4),
        Text(
          quizOutcomeText(outcome),
          style: AppText.tag.copyWith(color: color),
        ),
      ],
    );
  }
}

class _AnswerReview extends StatelessWidget {
  const _AnswerReview({required this.outcome});
  final QuestionOutcome outcome;
  QuizQuestion get question => outcome.question;

  @override
  Widget build(BuildContext context) {
    if (question is ChronologicalOrderingQuestion) {
      return _OrderingReview(
        question: question as ChronologicalOrderingQuestion,
        answer: outcome.answer as OrderingAnswer?,
      );
    }
    final choice = question as ChoiceQuestion;
    final correct = choice.options
        .firstWhere((option) => option.id == choice.correctOptionId)
        .text;
    final selected = outcome.answer is OptionAnswer
        ? choice.options
              .firstWhere(
                (option) =>
                    option.id == (outcome.answer as OptionAnswer).optionId,
              )
              .text
        : null;
    if (outcome.kind == QuestionOutcomeKind.correct) {
      return _AnswerLine(label: 'Your answer', value: selected!);
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (selected != null) ...[
          _AnswerLine(
            label: 'Your answer',
            value: selected,
            color: AppColors.copperDark,
          ),
          const SizedBox(height: 8),
        ],
        _AnswerLine(label: 'Correct answer', value: correct),
      ],
    );
  }
}

class _AnswerLine extends StatelessWidget {
  const _AnswerLine({required this.label, required this.value, this.color});
  final String label;
  final String value;
  final Color? color;

  @override
  Widget build(BuildContext context) => MergeSemantics(
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          label,
          style: AppText.tag.copyWith(color: color ?? AppColors.mutedGray),
        ),
        const SizedBox(height: 2),
        Text(value, style: Theme.of(context).textTheme.titleMedium),
      ],
    ),
  );
}

/// The correct order, each row marked with where the player placed it.
class _OrderingReview extends StatelessWidget {
  const _OrderingReview({required this.question, required this.answer});
  final ChronologicalOrderingQuestion question;
  final OrderingAnswer? answer;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    final ids = question.correctOrderItemIds;
    final placed = answer?.orderedItemIds;
    return Semantics(
      container: true,
      label: 'Correct order',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            'Correct order',
            style: AppText.tag.copyWith(color: AppColors.mutedGray),
          ),
          const SizedBox(height: 4),
          for (var index = 0; index < ids.length; index++)
            Container(
              padding: const EdgeInsets.symmetric(vertical: 10),
              decoration: const BoxDecoration(
                border: Border(bottom: BorderSide(color: AppColors.hairline)),
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  SizedBox(
                    width: 28,
                    child: Text(
                      '${index + 1}.',
                      style: AppText.listYear.copyWith(fontSize: 16),
                    ),
                  ),
                  Expanded(
                    child: Text(
                      question.items
                          .firstWhere((item) => item.id == ids[index])
                          .text,
                      style: textTheme.bodyMedium,
                    ),
                  ),
                  if (placed != null) ...[
                    const SizedBox(width: 8),
                    _placement(placed.indexOf(ids[index]), index),
                  ],
                ],
              ),
            ),
        ],
      ),
    );
  }

  Widget _placement(int placedAt, int belongs) {
    final inPlace = placedAt == belongs;
    final color = inPlace ? AppColors.archivalCobalt : AppColors.copperDark;
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(inPlace ? Icons.check : Icons.close, size: 14, color: color),
        const SizedBox(width: 4),
        Text(
          inPlace
              ? quizOrdinal(placedAt + 1)
              : 'You: ${quizOrdinal(placedAt + 1)}',
          style: AppText.tag.copyWith(color: color),
        ),
      ],
    );
  }
}

class _ImageProvenance extends StatelessWidget {
  const _ImageProvenance({
    required this.image,
    required this.launcher,
    required this.questionId,
  });
  final QuizImage image;
  final SourceLauncher launcher;
  final String questionId;

  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.stretch,
    children: [
      Text('Attribution: ${image.attribution}'),
      if (image.creator != null) Text('Creator: ${image.creator}'),
      Text('License: ${image.license}'),
      QuizReviewExternalLink(
        key: ValueKey('$questionId:image-source'),
        label: image.source,
        semanticsLabel: 'Open image source: ${image.source}',
        url: image.sourceUrl,
        launcher: launcher,
      ),
      QuizReviewExternalLink(
        key: ValueKey('$questionId:image-license'),
        label: image.license,
        semanticsLabel: 'Open image license: ${image.license}',
        url: image.licenseUrl,
        launcher: launcher,
      ),
    ],
  );
}
