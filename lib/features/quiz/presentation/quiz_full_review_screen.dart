import 'package:flutter/material.dart';

import '../../../core/config/app_colors.dart';
import '../../../core/navigation/source_launcher.dart';
import '../domain/question_outcome.dart';
import '../domain/quiz_answer.dart';
import '../domain/quiz_image.dart';
import '../domain/quiz_question.dart';
import '../domain/quiz_result.dart';
import 'widgets/quiz_review_external_link.dart';

/// Pure presentation of a frozen result. It has no persistence, coordinator,
/// repository, or grading dependency and also works with decoded snapshots.
final class QuizFullReviewScreen extends StatelessWidget {
  const QuizFullReviewScreen({
    super.key,
    required this.result,
    required this.sourceLauncher,
    required this.onDone,
  });

  final QuizResult result;
  final SourceLauncher sourceLauncher;
  final VoidCallback onDone;

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(
      title: const Text(
        'Full review',
        style: TextStyle(
          fontFamily: 'Georgia',
          fontFamilyFallback: ['Times New Roman', 'serif'],
          fontSize: 21,
        ),
      ),
    ),
    body: Column(
      children: [
        Expanded(
          child: ListView.separated(
            key: const PageStorageKey('quiz-review-scroll'),
            padding: const EdgeInsets.fromLTRB(20, 16, 20, 108),
            itemCount: result.outcomes.length,
            itemBuilder: (context, index) => _ReviewQuestion(
              key: ValueKey('review-${result.outcomes[index].question.id}'),
              number: index + 1,
              outcome: result.outcomes[index],
              sourceLauncher: sourceLauncher,
            ),
            separatorBuilder: (_, _) => const SizedBox(height: 16),
          ),
        ),
        SafeArea(
          top: false,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(20, 8, 20, 12),
            child: SizedBox(
              width: double.infinity,
              child: FilledButton(
                onPressed: onDone,
                style: FilledButton.styleFrom(
                  minimumSize: const Size.fromHeight(48),
                ),
                child: const Text('Done'),
              ),
            ),
          ),
        ),
      ],
    ),
  );
}

class _ReviewQuestion extends StatelessWidget {
  const _ReviewQuestion({
    super.key,
    required this.number,
    required this.outcome,
    required this.sourceLauncher,
  });

  final int number;
  final QuestionOutcome outcome;
  final SourceLauncher sourceLauncher;

  QuizQuestion get question => outcome.question;

  @override
  Widget build(BuildContext context) => Semantics(
    container: true,
    label: 'Question $number: ${_outcomeLabel(outcome)}',
    child: Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.softIvory,
        border: Border.all(color: AppColors.paleStone),
        borderRadius: BorderRadius.circular(6),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            'Question $number · ${question.difficulty.name}',
            style: Theme.of(
              context,
            ).textTheme.labelLarge?.copyWith(color: AppColors.archivalCobalt),
          ),
          const SizedBox(height: 8),
          Semantics(
            header: true,
            child: Text(
              question.prompt,
              style: Theme.of(context).textTheme.titleLarge?.copyWith(
                fontFamily: 'Georgia',
                fontFamilyFallback: const ['Times New Roman', 'serif'],
              ),
            ),
          ),
          const SizedBox(height: 14),
          _OutcomeLabel(outcome: outcome),
          const SizedBox(height: 14),
          _AnswerReview(outcome: outcome),
          const Padding(
            padding: EdgeInsets.symmetric(vertical: 16),
            child: Divider(color: AppColors.mutedCopper),
          ),
          Text(question.explanation),
          const SizedBox(height: 16),
          Text('Sources', style: Theme.of(context).textTheme.titleSmall),
          for (final source in question.sources)
            QuizReviewExternalLink(
              key: ValueKey('${question.id}:source:${source.url}'),
              label: 'Open source: ${source.displayName}',
              url: source.url,
              launcher: sourceLauncher,
            ),
          if (question is ImageIdentificationQuestion) ...[
            const SizedBox(height: 12),
            _ImageProvenance(
              image: (question as ImageIdentificationQuestion).image,
              launcher: sourceLauncher,
              questionId: question.id,
            ),
          ],
        ],
      ),
    ),
  );
}

class _OutcomeLabel extends StatelessWidget {
  const _OutcomeLabel({required this.outcome});
  final QuestionOutcome outcome;

  @override
  Widget build(BuildContext context) {
    final (icon, text) = switch (outcome.kind) {
      QuestionOutcomeKind.correct => (Icons.check_circle_outline, 'Correct'),
      QuestionOutcomeKind.incorrect => (Icons.cancel_outlined, 'Incorrect'),
      QuestionOutcomeKind.timedOut => (Icons.timer_off_outlined, 'Timed out'),
      QuestionOutcomeKind.unanswered
          when outcome.unansweredReason == UnansweredReason.imageSkipped =>
        (Icons.skip_next_outlined, 'Skipped'),
      QuestionOutcomeKind.unanswered => (
        Icons.remove_circle_outline,
        'Not reached',
      ),
    };
    return Row(
      children: [
        Icon(icon, size: 20, color: AppColors.archivalCobalt),
        const SizedBox(width: 8),
        Text(text, style: Theme.of(context).textTheme.titleSmall),
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
      return Text('Your answer — $selected (Correct)');
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (selected != null) Text('Your answer: $selected'),
        if (selected != null) const SizedBox(height: 8),
        Text('Correct answer: $correct'),
      ],
    );
  }
}

class _OrderingReview extends StatelessWidget {
  const _OrderingReview({required this.question, required this.answer});
  final ChronologicalOrderingQuestion question;
  final OrderingAnswer? answer;

  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.stretch,
    children: [
      if (answer != null) ...[
        _OrderList(
          label: 'Your submitted order',
          ids: answer!.orderedItemIds,
          question: question,
        ),
        const SizedBox(height: 12),
      ],
      _OrderList(
        label: 'Correct order',
        ids: question.correctOrderItemIds,
        question: question,
      ),
    ],
  );
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
        Text(label, style: Theme.of(context).textTheme.titleSmall),
        const SizedBox(height: 4),
        for (var index = 0; index < ids.length; index++)
          Text(
            '${index + 1}. ${question.items.firstWhere((item) => item.id == ids[index]).text}',
          ),
      ],
    ),
  );
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
      Text('Image', style: Theme.of(context).textTheme.titleSmall),
      const SizedBox(height: 6),
      const Text('Image unavailable in review.'),
      const SizedBox(height: 6),
      Semantics(
        image: true,
        label: image.altText,
        child: Text('Alt text: ${image.altText}'),
      ),
      Text('Attribution: ${image.attribution}'),
      if (image.creator != null) Text('Creator: ${image.creator}'),
      Text('License: ${image.license}'),
      QuizReviewExternalLink(
        key: ValueKey('$questionId:image-source'),
        label: 'Open image source: ${image.source}',
        url: image.sourceUrl,
        launcher: launcher,
      ),
      QuizReviewExternalLink(
        key: ValueKey('$questionId:image-license'),
        label: 'Open image license: ${image.license}',
        url: image.licenseUrl,
        launcher: launcher,
      ),
    ],
  );
}

String _outcomeLabel(QuestionOutcome outcome) => switch (outcome.kind) {
  QuestionOutcomeKind.correct => 'Correct',
  QuestionOutcomeKind.incorrect => 'Incorrect',
  QuestionOutcomeKind.timedOut => 'Timed out',
  QuestionOutcomeKind.unanswered
      when outcome.unansweredReason == UnansweredReason.imageSkipped =>
    'Skipped',
  QuestionOutcomeKind.unanswered => 'Not reached',
};
