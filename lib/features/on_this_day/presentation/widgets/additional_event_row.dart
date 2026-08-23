import 'package:flutter/material.dart';

import '../../../../core/config/app_colors.dart';
import '../../domain/historical_event_summary.dart';

class AdditionalEventRow extends StatelessWidget {
  const AdditionalEventRow({
    super.key,
    required this.event,
    required this.onTap,
  });

  final HistoricalEventSummary event;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      label: '${event.year}, ${event.title}',
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
                    event.year,
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      color: AppColors.archivalCobalt,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
                Expanded(
                  child: Text(
                    event.title,
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      color: AppColors.deepInk,
                      fontWeight: FontWeight.w400,
                      height: 1.35,
                    ),
                  ),
                ),
                const SizedBox(width: 14),
                const Icon(
                  Icons.chevron_right,
                  color: AppColors.mutedGray,
                  semanticLabel: 'Open event',
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
