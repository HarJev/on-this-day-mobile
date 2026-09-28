import 'package:flutter/material.dart';

import '../../../../core/config/app_colors.dart';
import '../../domain/recent_day.dart';

class RecentDayRow extends StatelessWidget {
  const RecentDayRow({super.key, required this.day, required this.onTap});

  final RecentDay day;
  final VoidCallback onTap;

  static String dateLabelFor(RecentDay day) =>
      day.daysAgo == 1 ? 'Yesterday' : day.displayDate;

  @override
  Widget build(BuildContext context) {
    final event = day.featuredEvent;
    final dateLabel = dateLabelFor(day);
    final textTheme = Theme.of(context).textTheme;

    return Semantics(
      button: true,
      label: '$dateLabel, ${event.year}, ${event.title}',
      excludeSemantics: true,
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          child: Container(
            constraints: const BoxConstraints(minHeight: 72),
            decoration: const BoxDecoration(
              border: Border(bottom: BorderSide(color: AppColors.paleStone)),
            ),
            padding: const EdgeInsets.symmetric(vertical: 14),
            child: Row(
              children: [
                SizedBox(
                  width: 78,
                  child: Text(
                    dateLabel,
                    style: textTheme.titleSmall?.copyWith(
                      color: AppColors.archivalCobalt,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        event.title,
                        style: textTheme.titleMedium?.copyWith(
                          color: AppColors.deepInk,
                          fontWeight: FontWeight.w400,
                          height: 1.35,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        event.year,
                        style: textTheme.bodyMedium?.copyWith(
                          color: AppColors.mutedGray,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 14),
                const Icon(Icons.chevron_right, color: AppColors.mutedGray),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
