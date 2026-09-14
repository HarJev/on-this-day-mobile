import 'package:flutter/material.dart';
import 'package:flutter/semantics.dart';

import '../../../../core/config/app_colors.dart';
import '../../domain/quiz_question.dart';

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
      Focus(
        focusNode: widget.headingFocus,
        child: Semantics(
          header: true,
          child: Text(
            widget.question.prompt,
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
      // This viewport is deliberately non-scrollable; the gameplay page owns
      // the only effective scroll position while Reorderable provides drag.
      ReorderableListView.builder(
        shrinkWrap: true,
        primary: false,
        physics: const NeverScrollableScrollPhysics(),
        buildDefaultDragHandles: false,
        itemCount: widget.orderingDraft.length,
        onReorder: _reorder,
        proxyDecorator: (child, _, _) => child,
        itemBuilder: (context, index) {
          final item = _itemFor(widget.orderingDraft[index]);
          return Padding(
            key: ValueKey(item.id),
            padding: const EdgeInsets.only(bottom: 10),
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
    ],
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
        borderRadius: BorderRadius.circular(6),
        side: const BorderSide(color: AppColors.paleStone),
      ),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(12, 8, 6, 8),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            SizedBox(
              width: 32,
              child: Text(
                '${index + 1}',
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.titleMedium,
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                item.text,
                style: const TextStyle(
                  color: AppColors.deepInk,
                  fontSize: 17,
                  height: 1.35,
                ),
              ),
            ),
            const SizedBox(width: 4),
            Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                _MoveButton(
                  tooltip: 'Move ${item.text} up',
                  icon: Icons.keyboard_arrow_up,
                  onPressed: onMoveUp,
                ),
                _MoveButton(
                  tooltip: 'Move ${item.text} down',
                  icon: Icons.keyboard_arrow_down,
                  onPressed: onMoveDown,
                ),
              ],
            ),
            ReorderableDragStartListener(
              index: index,
              child: Semantics(
                button: true,
                label: 'Drag ${item.text} to reorder',
                child: SizedBox(
                  key: Key('ordering-drag-${item.id}'),
                  width: 48,
                  height: 48,
                  child: const Icon(
                    Icons.drag_handle,
                    color: AppColors.mutedGray,
                  ),
                ),
              ),
            ),
          ],
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
    constraints: const BoxConstraints.tightFor(width: 48, height: 48),
    padding: EdgeInsets.zero,
    onPressed: onPressed,
    icon: Icon(icon),
  );
}
