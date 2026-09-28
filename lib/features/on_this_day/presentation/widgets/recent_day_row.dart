import 'package:flutter/material.dart';

import '../../../../core/config/app_colors.dart';
import '../../domain/recent_day.dart';
import 'additional_event_row.dart';

class RecentDayRow extends StatelessWidget {
  const RecentDayRow({super.key, required this.day, required this.onTap});

  final RecentDay day;
  final VoidCallback onTap;

  static String dateLabelFor(RecentDay day) =>
      day.daysAgo == 1 ? 'Yesterday' : day.displayDate;

  static String _distanceFor(RecentDay day) =>
      day.daysAgo == 1 ? 'Yesterday' : '${day.daysAgo} days ago';

  @override
  Widget build(BuildContext context) {
    final event = day.featuredEvent;
    final textTheme = Theme.of(context).textTheme;

    return Semantics(
      button: true,
      label: '${dateLabelFor(day)}, ${event.year}, ${event.title}',
      excludeSemantics: true,
      child: EditorialListRow(
        onTap: onTap,
        leadingWidth: 64,
        leading: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              day.displayDate,
              style: textTheme.labelLarge?.copyWith(
                fontSize: 14,
                color: AppColors.archivalCobalt,
              ),
            ),
            Text(
              _distanceFor(day),
              style: textTheme.labelSmall?.copyWith(
                color: AppColors.mutedGray,
                fontWeight: FontWeight.w400,
              ),
            ),
          ],
        ),
        child: Text.rich(
          TextSpan(
            children: [
              TextSpan(
                text: '${event.year} · ',
                style: const TextStyle(color: AppColors.mutedGray),
              ),
              TextSpan(text: event.title),
            ],
          ),
          style: textTheme.bodyMedium?.copyWith(height: 1.4),
        ),
      ),
    );
  }
}
