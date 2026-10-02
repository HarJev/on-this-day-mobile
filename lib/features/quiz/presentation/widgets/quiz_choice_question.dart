import 'package:flutter/material.dart';

import '../../../../core/config/app_colors.dart';
import '../../../../core/config/app_theme.dart';
import '../../domain/question_outcome.dart';
import '../../domain/quiz_answer.dart';
import '../../domain/quiz_question.dart';
import 'quiz_design.dart';

class QuizChoiceQuestion extends StatelessWidget {
  const QuizChoiceQuestion({
    super.key,
    required this.question,
    required this.headingFocus,
    required this.onAnswer,
    this.outcome,
    this.image,
  });
  final ChoiceQuestion question;
  final FocusNode headingFocus;
  final void Function(String) onAnswer;
  final QuestionOutcome? outcome;
  final Widget? image;

  @override
  Widget build(BuildContext context) {
    final answered = outcome != null;
    final options = question.options;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (!answered) QuizTypeLabel(type: question.type),
        Focus(
          focusNode: headingFocus,
          child: Semantics(
            header: true,
            child: Text(
              question.prompt,
              key: const Key('quiz-heading'),
              style: answered
                  ? AppText.questionPromptAnswered
                  : AppText.questionPrompt,
            ),
          ),
        ),
        if (!answered && image == null) ...[
          const SizedBox(height: 10),
          const _CommitHint(),
        ],
        const SizedBox(height: 14),
        ?image,
        if (question is TrueFalseQuestion)
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              for (var i = 0; i < options.length; i++) ...[
                if (i > 0) const SizedBox(width: 12),
                Expanded(child: _tile(context, options[i])),
              ],
            ],
          )
        else if (question is ImageIdentificationQuestion && _fitsGrid(context))
          Column(
            children: [
              for (var row = 0; row < options.length; row += 2)
                Padding(
                  padding: const EdgeInsets.only(bottom: 10),
                  child: IntrinsicHeight(
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        for (var i = row; i < row + 2; i++) ...[
                          if (i > row) const SizedBox(width: 10),
                          Expanded(
                            child: i < options.length
                                ? _row(context, options[i], i)
                                : const SizedBox.shrink(),
                          ),
                        ],
                      ],
                    ),
                  ),
                ),
            ],
          )
        else
          for (var i = 0; i < options.length; i++)
            Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: _row(context, options[i], i),
            ),
      ],
    );
  }

  /// Two columns only while every option stays short at this text size.
  bool _fitsGrid(BuildContext context) =>
      MediaQuery.textScalerOf(context).scale(16) <= 20 &&
      question.options.every((o) => o.text.length <= 24);

  QuizMark _markFor(QuizOption option) {
    final outcome = this.outcome;
    if (outcome == null) return QuizMark.idle;
    if (option.id == question.correctOptionId) return QuizMark.correct;
    return _selected(option) ? QuizMark.wrong : QuizMark.dim;
  }

  bool _selected(QuizOption option) =>
      outcome?.answer is OptionAnswer &&
      (outcome!.answer as OptionAnswer).optionId == option.id;

  String _tagFor(QuizOption option) {
    final correct = outcome != null && option.id == question.correctOptionId;
    if (correct && _selected(option)) return 'Your answer';
    if (correct) return 'Correct answer';
    if (_selected(option)) return 'Your answer';
    return '';
  }

  Widget _row(BuildContext context, QuizOption option, int index) {
    final mark = _markFor(option);
    final tag = _tagFor(option);
    final textTheme = Theme.of(context).textTheme;
    final thick = mark == QuizMark.correct || mark == QuizMark.wrong;
    return _Choice(
      option: option,
      selected: _selected(option),
      enabled: outcome == null,
      mark: mark,
      radius: 12,
      onTap: () => onAnswer(option.id),
      child: Padding(
        padding: EdgeInsets.symmetric(
          horizontal: thick ? 13 : 14,
          vertical: thick ? 11 : 12,
        ),
        child: Row(
          children: [
            _LetterBadge(letter: String.fromCharCode(65 + index), mark: mark),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    option.text,
                    style: textTheme.bodyLarge?.copyWith(
                      height: 1.35,
                      color: mark == QuizMark.dim
                          ? AppColors.mutedGray
                          : AppColors.deepInk,
                      fontWeight: mark == QuizMark.correct
                          ? FontWeight.w600
                          : FontWeight.w400,
                    ),
                  ),
                  if (tag.isNotEmpty)
                    Padding(
                      padding: const EdgeInsets.only(top: 2),
                      child: Text(
                        tag,
                        style: textTheme.labelMedium?.copyWith(
                          color: mark.tagColor,
                        ),
                      ),
                    ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _tile(BuildContext context, QuizOption option) {
    final mark = _markFor(option);
    final tag = _tagFor(option);
    final textTheme = Theme.of(context).textTheme;
    final isTrue = option.text.trim().toLowerCase() == 'true';
    final iconColor = switch (mark) {
      QuizMark.correct => AppColors.softIvory,
      QuizMark.wrong => AppColors.softIvory,
      QuizMark.dim => AppColors.mutedGray,
      QuizMark.idle => AppColors.deepInk,
    };
    final circleFill = switch (mark) {
      QuizMark.correct => AppColors.archivalCobalt,
      QuizMark.wrong => AppColors.mutedCopper,
      _ => AppColors.warmPaper,
    };
    return _Choice(
      option: option,
      selected: _selected(option),
      enabled: outcome == null,
      mark: mark,
      radius: 16,
      onTap: () => onAnswer(option.id),
      child: ConstrainedBox(
        constraints: const BoxConstraints(minHeight: 140),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 16),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                width: 52,
                height: 52,
                decoration: BoxDecoration(
                  color: circleFill,
                  shape: BoxShape.circle,
                  border: mark == QuizMark.idle || mark == QuizMark.dim
                      ? Border.all(color: AppColors.paleStone)
                      : null,
                ),
                child: Icon(
                  isTrue ? Icons.check : Icons.close,
                  color: iconColor,
                ),
              ),
              const SizedBox(height: 10),
              Text(
                option.text,
                textAlign: TextAlign.center,
                style: AppText.sectionHeader.copyWith(
                  fontSize: 24,
                  color: mark == QuizMark.dim
                      ? AppColors.mutedGray
                      : AppColors.deepInk,
                ),
              ),
              if (tag.isNotEmpty)
                Padding(
                  padding: const EdgeInsets.only(top: 4),
                  child: Text(
                    tag,
                    textAlign: TextAlign.center,
                    style: textTheme.labelMedium?.copyWith(
                      color: mark.tagColor,
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

class _Choice extends StatelessWidget {
  const _Choice({
    required this.option,
    required this.selected,
    required this.enabled,
    required this.mark,
    required this.radius,
    required this.onTap,
    required this.child,
  });

  final QuizOption option;
  final bool selected, enabled;
  final QuizMark mark;
  final double radius;
  final VoidCallback onTap;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final duration = MediaQuery.disableAnimationsOf(context)
        ? Duration.zero
        : const Duration(milliseconds: 160);
    return Semantics(
      button: true,
      enabled: enabled,
      selected: selected,
      child: AnimatedContainer(
        duration: duration,
        curve: Curves.easeOut,
        decoration: BoxDecoration(
          color: mark.fill,
          borderRadius: BorderRadius.circular(radius),
          border: Border.fromBorderSide(mark.border),
        ),
        child: Material(
          type: MaterialType.transparency,
          child: InkWell(
            key: Key('option-${option.id}'),
            borderRadius: BorderRadius.circular(radius),
            highlightColor: AppColors.pressedFill,
            splashColor: Colors.transparent,
            onTap: enabled ? onTap : null,
            child: ConstrainedBox(
              constraints: const BoxConstraints(minHeight: 56),
              child: child,
            ),
          ),
        ),
      ),
    );
  }
}

class _LetterBadge extends StatelessWidget {
  const _LetterBadge({required this.letter, required this.mark});

  final String letter;
  final QuizMark mark;

  @override
  Widget build(BuildContext context) {
    final duration = MediaQuery.disableAnimationsOf(context)
        ? Duration.zero
        : const Duration(milliseconds: 160);
    final (fill, border, content) = switch (mark) {
      QuizMark.correct => (
        AppColors.archivalCobalt,
        null,
        const Icon(
          Icons.check,
          key: ValueKey('check'),
          size: 16,
          color: AppColors.softIvory,
        ),
      ),
      QuizMark.wrong => (
        AppColors.mutedCopper,
        null,
        const Icon(
          Icons.close,
          key: ValueKey('close'),
          size: 16,
          color: AppColors.softIvory,
        ),
      ),
      _ => (
        Colors.transparent,
        mark == QuizMark.dim ? AppColors.hairline : AppColors.paleStone,
        Text(
          letter,
          key: ValueKey(letter),
          style: AppText.eyebrow.copyWith(color: AppColors.mutedGray),
        ),
      ),
    };
    return ExcludeSemantics(
      child: AnimatedContainer(
        duration: duration,
        width: 28,
        height: 28,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: fill,
          shape: BoxShape.circle,
          border: border == null ? null : Border.all(color: border),
        ),
        child: AnimatedSwitcher(
          duration: duration,
          transitionBuilder: (child, animation) => FadeTransition(
            opacity: animation,
            child: ScaleTransition(
              scale: Tween<double>(begin: 0.9, end: 1).animate(animation),
              child: child,
            ),
          ),
          child: content,
        ),
      ),
    );
  }
}

class _CommitHint extends StatelessWidget {
  const _CommitHint();

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        const Icon(
          Icons.touch_app_outlined,
          size: 16,
          color: AppColors.mutedGray,
        ),
        const SizedBox(width: 6),
        Flexible(
          child: Text(
            'Tap an answer to lock it in',
            style: Theme.of(context).textTheme.bodySmall,
          ),
        ),
      ],
    );
  }
}
