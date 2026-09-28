import 'package:flutter/material.dart';

import '../../../../core/config/app_colors.dart';
import '../../../../core/config/app_theme.dart';
import '../../../../core/navigation/source_launcher.dart';
import '../../domain/question_outcome.dart';
import '../../domain/quiz_rules.dart';
import '../../domain/quiz_source.dart';
import 'quiz_source_row.dart';

/// Shared Quiz building blocks from the Claude Design refresh (DESIGN.md
/// section 16). Every state pairs colour with an icon and text.

/// The copper icon and label that give each question type its identity.
class QuizTypeLabel extends StatelessWidget {
  const QuizTypeLabel({super.key, required this.type});

  final QuizQuestionType type;

  static (IconData, String) of(QuizQuestionType type) => switch (type) {
    QuizQuestionType.multipleChoice => (
      Icons.format_list_bulleted,
      'Multiple choice',
    ),
    QuizQuestionType.trueFalse => (Icons.rule, 'True or false'),
    QuizQuestionType.imageIdentification => (
      Icons.image_outlined,
      'Identify the image',
    ),
    QuizQuestionType.chronologicalOrdering => (Icons.swap_vert, 'Put in order'),
  };

  @override
  Widget build(BuildContext context) {
    final (icon, label) = of(type);
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Row(
        children: [
          Icon(icon, size: 18, color: AppColors.mutedCopper),
          const SizedBox(width: 8),
          Flexible(
            child: Text(
              label,
              style: AppText.eyebrow.copyWith(color: AppColors.mutedGray),
            ),
          ),
        ],
      ),
    );
  }
}

/// Visual state shared by answer rows, true/false tiles and result cells.
enum QuizMark { idle, correct, wrong, dim }

extension QuizMarkStyle on QuizMark {
  Color get fill => switch (this) {
    QuizMark.idle => AppColors.softIvory,
    QuizMark.correct => AppColors.cobaltTint,
    QuizMark.wrong => AppColors.copperTint,
    QuizMark.dim => Colors.transparent,
  };

  BorderSide get border => switch (this) {
    QuizMark.idle => const BorderSide(color: AppColors.paleStone),
    QuizMark.correct => const BorderSide(
      color: AppColors.archivalCobalt,
      width: 2,
    ),
    QuizMark.wrong => const BorderSide(color: AppColors.mutedCopper, width: 2),
    QuizMark.dim => const BorderSide(color: AppColors.hairline),
  };

  Color get tagColor => switch (this) {
    QuizMark.correct => AppColors.archivalCobalt,
    QuizMark.wrong => AppColors.copperDark,
    _ => AppColors.mutedGray,
  };
}

/// The circle beside a feedback title: its fill, ring and icon carry the
/// outcome together with the words.
class QuizOutcomeBadge extends StatelessWidget {
  const QuizOutcomeBadge({super.key, required this.kind, this.size = 36});

  final QuestionOutcomeKind kind;
  final double size;

  @override
  Widget build(BuildContext context) {
    final (fill, ring, icon, color) = switch (kind) {
      QuestionOutcomeKind.correct => (
        AppColors.archivalCobalt,
        null,
        Icons.check,
        AppColors.softIvory,
      ),
      QuestionOutcomeKind.incorrect => (
        Colors.transparent,
        AppColors.mutedCopper,
        Icons.close,
        AppColors.copperDark,
      ),
      QuestionOutcomeKind.timedOut => (
        Colors.transparent,
        AppColors.deepInk,
        Icons.hourglass_bottom,
        AppColors.deepInk,
      ),
      QuestionOutcomeKind.unanswered => (
        AppColors.softWarmGray,
        null,
        Icons.redo,
        AppColors.deepInk,
      ),
    };
    return ExcludeSemantics(
      child: Container(
        width: size,
        height: size,
        decoration: BoxDecoration(
          color: fill,
          shape: BoxShape.circle,
          border: ring == null ? null : Border.all(color: ring, width: 2),
        ),
        child: Icon(icon, size: size * 0.55, color: color),
      ),
    );
  }
}

/// One quiet "Sources (n)" row. In feedback it opens a bottom sheet; in
/// Review it expands in place. Links never sit up front.
class QuizSourcesDisclosure extends StatefulWidget {
  const QuizSourcesDisclosure({
    super.key,
    required this.sources,
    required this.launcher,
    this.inline = false,
  });

  final List<QuizSource> sources;
  final SourceLauncher launcher;

  /// Expands in place (Review) rather than opening a sheet (feedback).
  final bool inline;

  @override
  State<QuizSourcesDisclosure> createState() => _QuizSourcesDisclosureState();
}

class _QuizSourcesDisclosureState extends State<QuizSourcesDisclosure> {
  bool _expanded = false;

  @override
  Widget build(BuildContext context) {
    final label = 'Sources (${widget.sources.length})';
    final reduceMotion = MediaQuery.disableAnimationsOf(context);
    final trailing = widget.inline
        ? (_expanded ? Icons.expand_less : Icons.expand_more)
        : Icons.chevron_right;
    return DecoratedBox(
      decoration: const BoxDecoration(
        border: Border(
          top: BorderSide(color: AppColors.hairline),
          bottom: BorderSide(color: AppColors.hairline),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Semantics(
            button: true,
            expanded: widget.inline ? _expanded : null,
            label: label,
            excludeSemantics: true,
            child: InkWell(
              onTap: widget.inline
                  ? () => setState(() => _expanded = !_expanded)
                  : () => _showSheet(context),
              child: ConstrainedBox(
                constraints: const BoxConstraints(minHeight: 48),
                child: Row(
                  children: [
                    const Icon(
                      Icons.menu_book_outlined,
                      size: 19,
                      color: AppColors.mutedGray,
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        label,
                        style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ),
                    Icon(trailing, color: AppColors.mutedGray),
                  ],
                ),
              ),
            ),
          ),
          if (widget.inline)
            AnimatedSize(
              duration: reduceMotion
                  ? Duration.zero
                  : const Duration(milliseconds: 180),
              alignment: Alignment.topCenter,
              child: _expanded
                  ? Padding(
                      padding: const EdgeInsets.only(left: 29, bottom: 4),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          for (final source in widget.sources)
                            QuizSourceRow(
                              key: ValueKey(source.url),
                              source: source,
                              launcher: widget.launcher,
                            ),
                        ],
                      ),
                    )
                  : const SizedBox(width: double.infinity),
            ),
        ],
      ),
    );
  }

  Future<void> _showSheet(BuildContext context) {
    return showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      builder: (sheetContext) => SafeArea(
        top: false,
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(20, 0, 8, 20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Semantics(
                      header: true,
                      child: Text(
                        'Sources',
                        style: Theme.of(sheetContext).textTheme.titleLarge,
                      ),
                    ),
                  ),
                  IconButton(
                    tooltip: 'Close',
                    onPressed: () => Navigator.of(sheetContext).pop(),
                    icon: const Icon(Icons.close),
                  ),
                ],
              ),
              const SizedBox(height: 4),
              Padding(
                padding: const EdgeInsets.only(right: 12),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    for (final source in widget.sources)
                      QuizSourceRow(
                        key: ValueKey(source.url),
                        source: source,
                        launcher: widget.launcher,
                      ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// "1st", "2nd", "3rd", "4th" for ordering placements.
String quizOrdinal(int n) => switch (n) {
  1 => '1st',
  2 => '2nd',
  3 => '3rd',
  _ => '${n}th',
};

/// Words for a committed outcome, shared by Results and Review.
String quizOutcomeText(QuestionOutcome outcome) => switch (outcome.kind) {
  QuestionOutcomeKind.correct => 'Correct',
  QuestionOutcomeKind.incorrect => 'Incorrect',
  QuestionOutcomeKind.timedOut => 'Timed out',
  QuestionOutcomeKind.unanswered
      when outcome.unansweredReason == UnansweredReason.imageSkipped =>
    'Skipped',
  QuestionOutcomeKind.unanswered => 'Not reached',
};

QuizMark quizMarkFor(QuestionOutcomeKind kind) => switch (kind) {
  QuestionOutcomeKind.correct => QuizMark.correct,
  QuestionOutcomeKind.incorrect ||
  QuestionOutcomeKind.timedOut => QuizMark.wrong,
  QuestionOutcomeKind.unanswered => QuizMark.dim,
};

/// The small rounded pill that names an outcome in Review.
class QuizStatusPill extends StatelessWidget {
  const QuizStatusPill({super.key, required this.outcome});

  final QuestionOutcome outcome;

  @override
  Widget build(BuildContext context) {
    final (icon, fill, color) = switch (outcome.kind) {
      QuestionOutcomeKind.correct => (
        Icons.check,
        AppColors.cobaltTint,
        AppColors.archivalCobalt,
      ),
      QuestionOutcomeKind.incorrect => (
        Icons.close,
        AppColors.copperTint,
        AppColors.copperDark,
      ),
      QuestionOutcomeKind.timedOut => (
        Icons.hourglass_bottom,
        AppColors.copperTint,
        AppColors.copperDark,
      ),
      QuestionOutcomeKind.unanswered => (
        outcome.unansweredReason == UnansweredReason.imageSkipped
            ? Icons.redo
            : Icons.remove,
        AppColors.softWarmGray,
        AppColors.deepInk,
      ),
    };
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: fill,
        borderRadius: BorderRadius.circular(999),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          ExcludeSemantics(child: Icon(icon, size: 15, color: color)),
          const SizedBox(width: 5),
          Flexible(
            child: Text(
              quizOutcomeText(outcome),
              style: AppText.tag.copyWith(fontSize: 13, color: color),
            ),
          ),
        ],
      ),
    );
  }
}

/// One marked cell per question, five to a row, in question order.
class QuizResultStrip extends StatelessWidget {
  const QuizResultStrip({
    super.key,
    required this.outcomes,
    this.showTypes = false,
  });

  final List<QuestionOutcome> outcomes;

  /// Adds each question's type icon under its cell (short rounds only).
  final bool showTypes;

  @override
  Widget build(BuildContext context) => LayoutBuilder(
    builder: (context, constraints) {
      const gap = 8.0;
      final width = (constraints.maxWidth - gap * 4) / 5;
      return Wrap(
        spacing: gap,
        runSpacing: gap,
        children: [
          for (var i = 0; i < outcomes.length; i++)
            Semantics(
              label: 'Question ${i + 1}: ${quizOutcomeText(outcomes[i])}',
              excludeSemantics: true,
              child: SizedBox(
                width: width,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    _cell(outcomes[i]),
                    if (showTypes) ...[
                      const SizedBox(height: 6),
                      Icon(
                        QuizTypeLabel.of(outcomes[i].question.type).$1,
                        applyTextScaling: false,
                        size: 16,
                        color: AppColors.mutedGray,
                      ),
                    ],
                  ],
                ),
              ),
            ),
        ],
      );
    },
  );

  Widget _cell(QuestionOutcome outcome) {
    final mark = quizMarkFor(outcome.kind);
    final dim = mark == QuizMark.dim;
    return Container(
      height: 44,
      decoration: BoxDecoration(
        color: dim ? AppColors.softWarmGray : mark.fill,
        borderRadius: BorderRadius.circular(12),
        border: dim
            ? null
            : Border.fromBorderSide(mark.border.copyWith(width: 1.5)),
      ),
      child: Icon(
        switch (mark) {
          QuizMark.correct => Icons.check,
          QuizMark.wrong => Icons.close,
          _ => Icons.remove,
        },
        size: 20,
        color: dim ? AppColors.mutedGray : mark.tagColor,
      ),
    );
  }
}

/// A quiet row that expands in place, used for Review's image credit.
class QuizDisclosure extends StatefulWidget {
  const QuizDisclosure({
    super.key,
    required this.icon,
    required this.label,
    required this.child,
  });

  final IconData icon;
  final String label;
  final Widget child;

  @override
  State<QuizDisclosure> createState() => _QuizDisclosureState();
}

class _QuizDisclosureState extends State<QuizDisclosure> {
  bool _expanded = false;

  @override
  Widget build(BuildContext context) {
    final reduceMotion = MediaQuery.disableAnimationsOf(context);
    return DecoratedBox(
      decoration: const BoxDecoration(
        border: Border(top: BorderSide(color: AppColors.hairline)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Semantics(
            button: true,
            expanded: _expanded,
            label: widget.label,
            excludeSemantics: true,
            child: InkWell(
              onTap: () => setState(() => _expanded = !_expanded),
              child: ConstrainedBox(
                constraints: const BoxConstraints(minHeight: 48),
                child: Row(
                  children: [
                    Icon(widget.icon, size: 19, color: AppColors.mutedGray),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        widget.label,
                        style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ),
                    Icon(
                      _expanded ? Icons.expand_less : Icons.expand_more,
                      color: AppColors.mutedGray,
                    ),
                  ],
                ),
              ),
            ),
          ),
          AnimatedSize(
            duration: reduceMotion
                ? Duration.zero
                : const Duration(milliseconds: 180),
            alignment: Alignment.topCenter,
            child: _expanded
                ? Padding(
                    padding: const EdgeInsets.only(left: 29, bottom: 8),
                    child: widget.child,
                  )
                : const SizedBox(width: double.infinity),
          ),
        ],
      ),
    );
  }
}
