import 'package:flutter/material.dart';

import '../../../../core/config/app_colors.dart';
import '../../../../core/config/app_theme.dart';

/// Question position, the session timer (Daily total or timed Quick Play
/// question time; none when untimed) and a segmented progress bar.
class QuizGameplayHeader extends StatelessWidget {
  const QuizGameplayHeader({
    super.key,
    required this.daily,
    required this.index,
    required this.count,
    required this.remaining,
  });
  final bool daily;
  final int index, count;
  final Duration? remaining;

  static String timerText(bool daily, int seconds) {
    final clock =
        '${(seconds ~/ 60).toString().padLeft(2, '0')}:'
        '${(seconds % 60).toString().padLeft(2, '0')}';
    return '${daily ? 'Total time' : 'Question time'} $clock';
  }

  @override
  Widget build(BuildContext context) {
    final seconds = remaining == null
        ? null
        : (remaining!.inMilliseconds / 1000).ceil();
    final textTheme = Theme.of(context).textTheme;
    final urgent = seconds != null && seconds <= 5;
    final timerColor = urgent ? AppColors.copperDark : AppColors.archivalCobalt;
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 12, 20, 10),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          ConstrainedBox(
            constraints: const BoxConstraints(minHeight: 28),
            child: Wrap(
              alignment: WrapAlignment.spaceBetween,
              crossAxisAlignment: WrapCrossAlignment.center,
              spacing: 16,
              runSpacing: 4,
              children: [
                Text(
                  'Question ${index + 1} of $count',
                  style: textTheme.labelLarge?.copyWith(fontSize: 14),
                ),
                if (seconds != null)
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        urgent ? Icons.hourglass_bottom : Icons.timer_outlined,
                        size: 17,
                        color: timerColor,
                      ),
                      const SizedBox(width: 5),
                      Flexible(
                        child: Text(
                          timerText(daily, seconds),
                          key: const Key('quiz-timer'),
                          style: textTheme.labelLarge?.copyWith(
                            fontSize: 14,
                            color: timerColor,
                            fontFeatures: AppText.tabular,
                          ),
                        ),
                      ),
                    ],
                  ),
              ],
            ),
          ),
          const SizedBox(height: 6),
          Semantics(
            label: 'Question position',
            value: '${index + 1} of $count',
            excludeSemantics: true,
            child: Row(
              children: [
                for (var i = 0; i < count; i++) ...[
                  if (i > 0) const SizedBox(width: 3),
                  Expanded(
                    child: Container(
                      height: 3,
                      decoration: BoxDecoration(
                        color: i < index
                            ? AppColors.deepInk
                            : i == index
                            ? AppColors.archivalCobalt
                            : AppColors.paleStone,
                        borderRadius: BorderRadius.circular(2),
                      ),
                    ),
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}
