import 'package:flutter/material.dart';

import '../../../../core/config/app_colors.dart';
import '../../../../core/config/app_theme.dart';
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
      child: EditorialListRow(
        onTap: onTap,
        leadingWidth: 52,
        leading: Text(event.year, style: AppText.listYear),
        child: Text(
          event.title,
          style: Theme.of(context).textTheme.bodyLarge?.copyWith(height: 1.4),
        ),
      ),
    );
  }
}

/// The shared Today list row: a fixed year or date column, a title that
/// always wraps, and a chevron, over a stone hairline.
class EditorialListRow extends StatelessWidget {
  const EditorialListRow({
    super.key,
    required this.onTap,
    required this.leadingWidth,
    required this.leading,
    required this.child,
  });

  final VoidCallback onTap;
  final double leadingWidth;
  final Widget leading;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        child: Container(
          constraints: const BoxConstraints(minHeight: 60),
          decoration: const BoxDecoration(
            border: Border(bottom: BorderSide(color: AppColors.paleStone)),
          ),
          padding: const EdgeInsets.symmetric(vertical: 10),
          child: Row(
            children: [
              SizedBox(width: leadingWidth, child: leading),
              const SizedBox(width: 12),
              Expanded(child: child),
              const SizedBox(width: 12),
              const ExcludeSemantics(
                child: Icon(
                  Icons.chevron_right,
                  size: 22,
                  color: AppColors.mutedGray,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
