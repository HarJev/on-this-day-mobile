import 'package:flutter/material.dart';
import '../../../../core/config/app_colors.dart';

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
  @override
  Widget build(BuildContext context) {
    final seconds = remaining == null
        ? null
        : (remaining!.inMilliseconds / 1000).ceil();
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 6, 20, 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Wrap(
            alignment: WrapAlignment.spaceBetween,
            spacing: 16,
            runSpacing: 4,
            children: [
              Text(
                '${daily ? 'Daily Challenge' : 'Quick Play'} · ${index + 1} of $count',
                style: Theme.of(context).textTheme.labelLarge,
              ),
              if (seconds != null)
                Text(
                  '${daily ? 'Total' : 'Question'} ${(seconds ~/ 60).toString().padLeft(2, '0')}:${(seconds % 60).toString().padLeft(2, '0')}',
                  key: const Key('quiz-timer'),
                  style: TextStyle(
                    fontFeatures: const [FontFeature.tabularFigures()],
                    color: seconds <= 5
                        ? Theme.of(context).colorScheme.error
                        : AppColors.archivalCobalt,
                  ),
                ),
            ],
          ),
          const SizedBox(height: 7),
          LinearProgressIndicator(
            value: (index + 1) / count,
            minHeight: 2,
            semanticsLabel: 'Question position',
            backgroundColor: AppColors.paleStone,
          ),
        ],
      ),
    );
  }
}
