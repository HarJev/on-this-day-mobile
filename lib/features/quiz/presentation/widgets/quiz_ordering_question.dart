import 'package:flutter/material.dart';
import 'package:flutter/semantics.dart';

import '../../../../core/config/app_colors.dart';
import '../../../../core/config/app_theme.dart';
import '../../domain/quiz_question.dart';
import 'quiz_design.dart';

/// A controlled ordering editor. The session controller remains the source of
/// truth, so a deadline can reject a late movement before this widget renders it.
class QuizOrderingQuestion extends StatefulWidget {
  const QuizOrderingQuestion({
    super.key,
    required this.question,
    required this.headingFocus,
    required this.orderingDraft,
    required this.onDraftChanged,
  });

  final ChronologicalOrderingQuestion question;
  final FocusNode headingFocus;
  final List<String> orderingDraft;
  final bool Function(List<String> orderingDraft) onDraftChanged;

  @override
  State<QuizOrderingQuestion> createState() => _QuizOrderingQuestionState();
}

class _QuizOrderingQuestionState extends State<QuizOrderingQuestion> {
  void _move(int from, int to) {
    if (from == to) return;
    final draft = widget.orderingDraft.toList();
    final itemId = draft.removeAt(from);
    draft.insert(to, itemId);
    if (widget.onDraftChanged(draft)) {
      final item = _itemFor(itemId);
      if (MediaQuery.supportsAnnounceOf(context)) {
        SemanticsService.sendAnnouncement(
          View.of(context),
          '${item.text} moved to position ${to + 1}',
          Directionality.of(context),
        );
      }
    }
  }

  void _reorder(int oldIndex, int newIndex) {
    final target = newIndex > oldIndex ? newIndex - 1 : newIndex;
    _move(oldIndex, target);
  }

  QuizOrderingItem _itemFor(String id) =>
      widget.question.items.firstWhere((item) => item.id == id);

  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.stretch,
    children: [
      QuizTypeLabel(type: widget.question.type),
      Focus(
        focusNode: widget.headingFocus,
        child: Semantics(
          header: true,
          child: Text(
            widget.question.prompt,
            key: const Key('quiz-heading'),
            style: AppText.questionPrompt,
          ),
        ),
      ),
      const SizedBox(height: 14),
      const QuizTimelineEnd(earliest: true),
      // This viewport is deliberately non-scrollable; the gameplay page owns
      // the only effective scroll position while Reorderable provides drag.
      ReorderableListView.builder(
        shrinkWrap: true,
        primary: false,
        physics: const NeverScrollableScrollPhysics(),
        buildDefaultDragHandles: false,
        itemCount: widget.orderingDraft.length,
        onReorder: _reorder,
        proxyDecorator: (child, _, animation) => AnimatedBuilder(
          animation: animation,
          builder: (context, child) => Transform.translate(
            offset: Offset(0, -2 * animation.value),
            child: Transform.scale(
              scale: 1 + 0.01 * animation.value,
              child: child,
            ),
          ),
          child: _Lifted(child: child),
        ),
        itemBuilder: (context, index) {
          final item = _itemFor(widget.orderingDraft[index]);
          return QuizTimelineRow(
            key: ValueKey(item.id),
            index: index,
            count: widget.orderingDraft.length,
            node: QuizTimelineNode(label: '${index + 1}'),
            child: _OrderingRow(
              index: index,
              item: item,
              count: widget.orderingDraft.length,
              onMoveUp: index == 0 ? null : () => _move(index, index - 1),
              onMoveDown: index == widget.orderingDraft.length - 1
                  ? null
                  : () => _move(index, index + 1),
            ),
          );
        },
      ),
      const QuizTimelineEnd(earliest: false),
    ],
  );
}

/// Marks the dragged card: ink border and a soft lift shadow.
class _Lifted extends StatelessWidget {
  const _Lifted({required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) => Material(
    type: MaterialType.transparency,
    child: DecoratedBox(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(12),
        boxShadow: const [
          BoxShadow(
            color: Color(0x24171A1F),
            blurRadius: 24,
            offset: Offset(0, 10),
          ),
        ],
      ),
      child: child,
    ),
  );
}

/// "Earliest" above and "Latest" below the ordering timeline.
class QuizTimelineEnd extends StatelessWidget {
  const QuizTimelineEnd({super.key, required this.earliest});

  final bool earliest;

  @override
  Widget build(BuildContext context) => Padding(
    padding: EdgeInsets.only(
      left: 44,
      top: earliest ? 0 : 2,
      bottom: earliest ? 6 : 0,
    ),
    child: Row(
      children: [
        Icon(
          earliest ? Icons.north : Icons.south,
          size: 14,
          color: AppColors.mutedGray,
        ),
        const SizedBox(width: 4),
        Text(
          earliest ? 'Earliest' : 'Latest',
          style: AppText.tag.copyWith(color: AppColors.mutedGray),
        ),
      ],
    ),
  );
}

/// A 32px rail node: numbered while arranging, marked after submitting.
class QuizTimelineNode extends StatelessWidget {
  const QuizTimelineNode({super.key, this.label, this.inPlace});

  final String? label;

  /// Null while arranging; true or false once the order is submitted.
  final bool? inPlace;

  @override
  Widget build(BuildContext context) {
    final inPlace = this.inPlace;
    final (fill, border, content) = switch (inPlace) {
      true => (
        AppColors.archivalCobalt,
        null,
        const Icon(Icons.check, size: 16, color: AppColors.softIvory),
      ),
      false => (
        AppColors.warmPaper,
        Border.all(color: AppColors.mutedCopper, width: 2),
        const Icon(Icons.close, size: 16, color: AppColors.copperDark),
      ),
      null => (
        AppColors.warmPaper,
        Border.all(color: AppColors.paleStone, width: 1.5),
        Text(
          label ?? '',
          style: AppText.navTitle.copyWith(fontSize: 15, height: 1),
        ),
      ),
    };
    return ExcludeSemantics(
      child: Container(
        width: 32,
        height: 32,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: fill,
          shape: BoxShape.circle,
          border: border,
        ),
        child: content,
      ),
    );
  }
}

/// One row on the vertical timeline rail: a node on a stone line beside
/// its card. The line breaks above the first node and below the last.
class QuizTimelineRow extends StatelessWidget {
  const QuizTimelineRow({
    super.key,
    required this.index,
    required this.count,
    required this.node,
    required this.child,
  });

  final int index, count;
  final Widget node;
  final Widget child;

  @override
  Widget build(BuildContext context) => IntrinsicHeight(
    child: Row(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        SizedBox(
          width: 32,
          child: Stack(
            alignment: Alignment.topCenter,
            children: [
              Positioned(
                top: index == 0 ? 12 : 0,
                bottom: index == count - 1 ? null : 0,
                height: index == count - 1 ? 12 : null,
                child: const SizedBox(
                  width: 2,
                  child: ColoredBox(color: AppColors.paleStone),
                ),
              ),
              Padding(padding: const EdgeInsets.only(top: 12), child: node),
            ],
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Padding(
            padding: const EdgeInsets.only(bottom: 10),
            child: child,
          ),
        ),
      ],
    ),
  );
}

class _OrderingRow extends StatelessWidget {
  const _OrderingRow({
    required this.index,
    required this.item,
    required this.count,
    required this.onMoveUp,
    required this.onMoveDown,
  });

  final int index, count;
  final QuizOrderingItem item;
  final VoidCallback? onMoveUp, onMoveDown;

  @override
  Widget build(BuildContext context) => Semantics(
    container: true,
    label: 'Position ${index + 1} of $count: ${item.text}',
    child: Material(
      color: AppColors.softIvory,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: const BorderSide(color: AppColors.paleStone),
      ),
      child: ConstrainedBox(
        constraints: const BoxConstraints(minHeight: 56),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(0, 4, 2, 4),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              ReorderableDragStartListener(
                index: index,
                child: Semantics(
                  button: true,
                  label: 'Drag ${item.text} to reorder',
                  child: SizedBox(
                    key: Key('ordering-drag-${item.id}'),
                    width: 40,
                    height: 48,
                    child: const Icon(
                      Icons.drag_indicator,
                      size: 20,
                      color: AppColors.mutedGray,
                    ),
                  ),
                ),
              ),
              Expanded(
                child: Text(
                  item.text,
                  style: Theme.of(
                    context,
                  ).textTheme.bodyMedium?.copyWith(height: 1.35),
                ),
              ),
              _MoveButton(
                tooltip: 'Move ${item.text} up',
                icon: Icons.arrow_upward,
                onPressed: onMoveUp,
              ),
              _MoveButton(
                tooltip: 'Move ${item.text} down',
                icon: Icons.arrow_downward,
                onPressed: onMoveDown,
              ),
            ],
          ),
        ),
      ),
    ),
  );
}

class _MoveButton extends StatelessWidget {
  const _MoveButton({
    required this.tooltip,
    required this.icon,
    required this.onPressed,
  });

  final String tooltip;
  final IconData icon;
  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) => IconButton(
    key: Key(tooltip),
    tooltip: tooltip,
    constraints: const BoxConstraints.tightFor(width: 44, height: 48),
    padding: EdgeInsets.zero,
    color: AppColors.deepInk,
    disabledColor: AppColors.deepInk.withValues(alpha: 0.3),
    onPressed: onPressed,
    icon: Icon(icon, size: 20),
  );
}
