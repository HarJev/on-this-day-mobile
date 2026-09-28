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
    // Tiles share the tallest tile's height so large text never clips.
    return IntrinsicHeight(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          for (var index = 0; index < _counts.length; index++) ...[
            if (index > 0) const SizedBox(width: 10),
            Expanded(child: _segment(context, _counts[index])),
          ],
        ],
      ),
    );
  }

  Widget _segment(BuildContext context, int count) {
    final available = supported.contains(count);
    final enabled = available && onSelected != null;
    final isSelected = selected == count;
    final detail = detailFor?.call(count);
    final borderColor = isSelected
        ? available
              ? AppColors.archivalCobalt
              : AppColors.mutedCopper
        : AppColors.paleStone;
    final shape = RoundedRectangleBorder(
      borderRadius: BorderRadius.circular(14),
      side: BorderSide(color: borderColor, width: isSelected ? 2 : 1),
    );
    final textTheme = Theme.of(context).textTheme;
    return Semantics(
      button: true,
      selected: isSelected,
      enabled: enabled,
      label: [
        '$count questions',
        ?detail,
        if (!available) 'Unavailable',
      ].join(', '),
      excludeSemantics: true,
      child: Material(
        color: isSelected && available
            ? AppColors.cobaltTint
            : available
            ? AppColors.softIvory
            : Colors.transparent,
        shape: shape,
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: enabled ? () => onSelected!(count) : null,
          child: ConstrainedBox(
            constraints: const BoxConstraints(minHeight: 72),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 8),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      if (isSelected && available) ...[
                        const Icon(
                          Icons.check_circle,
                          size: 16,
                          color: AppColors.archivalCobalt,
                        ),
                        const SizedBox(width: 6),
                      ],
                      Flexible(
                        child: Text(
                          '$count',
                          style: textTheme.titleLarge?.copyWith(
                            fontSize: 24,
                            color: available
                                ? AppColors.deepInk
                                : AppColors.mutedGray,
                          ),
                        ),
                      ),
                    ],
                  ),
                  if (detail != null)
                    Text(detail, style: textTheme.bodySmall)
                  else if (!available)
                    Text(
                      'Unavailable',
                      style: textTheme.bodySmall,
                      maxLines: 1,
                      overflow: TextOverflow.fade,
                    ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  static const _counts = [5, 10, 20];
}
