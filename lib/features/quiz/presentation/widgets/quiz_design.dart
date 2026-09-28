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
