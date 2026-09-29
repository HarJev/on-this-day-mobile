import 'package:flutter/material.dart';

import '../../../../core/config/app_colors.dart';
import '../../domain/quiz_related_event.dart';
import 'quiz_design.dart';

/// Post-completion navigation only: titles can reveal quiz answers.
class QuizRelatedHistory extends StatelessWidget {
  const QuizRelatedHistory({
    super.key,
    required this.events,
    required this.onOpenEvent,
  });

  final List<QuizRelatedEvent> events;
  final ValueChanged<String> onOpenEvent;

  @override
  Widget build(BuildContext context) => QuizDisclosure(
    icon: Icons.menu_book_outlined,
    label: 'Related history',
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        for (final event in events)
          TextButton(
            key: ValueKey('related-event-${event.id}'),
            onPressed: () => onOpenEvent(event.id),
            style: TextButton.styleFrom(
              minimumSize: const Size.fromHeight(48),
              padding: const EdgeInsets.symmetric(vertical: 10),
              alignment: Alignment.centerLeft,
            ),
            child: Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        event.year,
                        style: Theme.of(context).textTheme.labelMedium
                            ?.copyWith(color: AppColors.archivalCobalt),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        event.title,
                        style: Theme.of(context).textTheme.bodyMedium,
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 12),
                const Icon(Icons.chevron_right, size: 20),
              ],
            ),
          ),
      ],
    ),
  );
}
