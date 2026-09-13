import 'package:flutter/material.dart';
import '../../../../core/config/app_colors.dart';
import '../../domain/quiz_question.dart';
import '../../domain/quiz_answer.dart';
import '../../domain/question_outcome.dart';

class QuizChoiceQuestion extends StatelessWidget {
  const QuizChoiceQuestion({
    super.key,
    required this.question,
    required this.headingFocus,
    required this.onAnswer,
    this.outcome,
  });
  final ChoiceQuestion question;
  final FocusNode headingFocus;
  final void Function(String) onAnswer;
  final QuestionOutcome? outcome;
  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.stretch,
    children: [
      Focus(
        focusNode: headingFocus,
        child: Semantics(
          header: true,
          child: Text(
            question.prompt,
            key: const Key('quiz-heading'),
            style: const TextStyle(
              fontFamily: 'Georgia',
              fontFamilyFallback: ['Times New Roman', 'serif'],
              fontSize: 26,
              height: 1.25,
              fontWeight: FontWeight.w500,
            ),
          ),
        ),
      ),
      const SizedBox(height: 20),
      for (final option in question.options)
        Padding(
          padding: const EdgeInsets.only(bottom: 10),
          child: _option(context, option),
        ),
    ],
  );
  Widget _option(BuildContext context, QuizOption option) {
    final selected =
        outcome?.answer is OptionAnswer &&
        (outcome!.answer as OptionAnswer).optionId == option.id;
    final correct = outcome != null && option.id == question.correctOptionId;
    final label = [
      if (selected) 'Your choice',
      if (correct) 'Correct answer',
    ].join(' · ');
    return Semantics(
      button: true,
      enabled: outcome == null,
      selected: selected,
      child: Material(
        color: AppColors.softIvory,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(6),
          side: BorderSide(
            color: correct ? AppColors.archivalCobalt : AppColors.paleStone,
          ),
        ),
        child: InkWell(
          key: Key('option-${option.id}'),
          borderRadius: BorderRadius.circular(6),
          onTap: outcome == null ? () => onAnswer(option.id) : null,
          child: ConstrainedBox(
            constraints: const BoxConstraints(minHeight: 56),
            child: Padding(
              padding: const EdgeInsets.all(14),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Text(
                    option.text,
                    style: const TextStyle(
                      fontSize: 17,
                      height: 1.35,
                      color: AppColors.deepInk,
                    ),
                  ),
                  if (label.isNotEmpty)
                    Padding(
                      padding: const EdgeInsets.only(top: 6),
                      child: Row(
                        children: [
                          Icon(
                            correct
                                ? Icons.check_circle_outline
                                : Icons.cancel_outlined,
                            size: 20,
                            color: correct
                                ? AppColors.archivalCobalt
                                : Theme.of(context).colorScheme.error,
                          ),
                          const SizedBox(width: 8),
                          Expanded(child: Text(label)),
                        ],
                      ),
                    ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
