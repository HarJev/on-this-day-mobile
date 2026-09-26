import 'package:flutter/material.dart';

import '../../../../core/config/app_colors.dart';

class QuizQuestionCountSelector extends StatelessWidget {
  const QuizQuestionCountSelector({
    super.key,
    required this.selected,
    required this.supported,
    required this.onSelected,
    this.detailFor,
  });

  final int selected;
  final Set<int> supported;
  final ValueChanged<int>? onSelected;
  final String? Function(int)? detailFor;

  @override
  Widget build(BuildContext context) {
    final scaled = MediaQuery.textScalerOf(context).scale(1) > 1.3;
    final segmentHeight = scaled ? 104.0 : 72.0;
    return ClipRRect(
      borderRadius: BorderRadius.circular(6),
      child: DecoratedBox(
        decoration: BoxDecoration(
          border: Border.all(color: AppColors.paleStone),
          borderRadius: BorderRadius.circular(6),
        ),
        child: Row(
          children: [
            for (var index = 0; index < _counts.length; index++) ...[
              if (index > 0)
                SizedBox(
                  width: 1,
                  height: segmentHeight,
                  child: const ColoredBox(color: AppColors.paleStone),
                ),
              Expanded(child: _segment(context, _counts[index], segmentHeight)),
            ],
          ],
        ),
      ),
    );
  }

  Widget _segment(BuildContext context, int count, double height) {
    final enabled = supported.contains(count) && onSelected != null;
    final isSelected = selected == count;
    final detail = detailFor?.call(count);
    return Semantics(
      button: true,
      selected: isSelected,
      enabled: enabled,
      label: [
        '$count questions',
        ?detail,
        if (!supported.contains(count)) 'Unavailable',
      ].join(', '),
      child: Material(
        color: isSelected && supported.contains(count)
            ? AppColors.softWarmGray
            : Colors.transparent,
        child: InkWell(
          onTap: enabled ? () => onSelected!(count) : null,
          child: Container(
            height: height,
            decoration: BoxDecoration(
              border: Border(
                bottom: BorderSide(
                  color: isSelected
                      ? supported.contains(count)
                            ? AppColors.archivalCobalt
                            : Theme.of(context).colorScheme.error
                      : Colors.transparent,
                  width: 3,
                ),
              ),
            ),
            padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 8),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    if (isSelected && supported.contains(count)) ...[
                      const Icon(Icons.check, size: 16),
                      const SizedBox(width: 4),
                    ],
                    Text(
                      '$count',
                      style: Theme.of(context).textTheme.titleLarge,
                    ),
                  ],
                ),
                if (detail != null)
                  Text(detail, style: Theme.of(context).textTheme.bodySmall)
                else if (!supported.contains(count))
                  Text(
                    'Unavailable',
                    style: Theme.of(context).textTheme.bodySmall,
                    maxLines: 1,
                    overflow: TextOverflow.fade,
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  static const _counts = [5, 10, 20];
}
