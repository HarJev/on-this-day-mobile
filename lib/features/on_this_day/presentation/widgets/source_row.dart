import 'package:flutter/material.dart';

import '../../../../core/config/app_colors.dart';
import '../../domain/event_source.dart';

class SourceRow extends StatelessWidget {
  const SourceRow({super.key, required this.source, required this.onTap});

  final EventSource source;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      label: 'Open source: ${source.name}',
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          child: Container(
            constraints: const BoxConstraints(minHeight: 54),
            decoration: const BoxDecoration(
              border: Border(bottom: BorderSide(color: AppColors.paleStone)),
            ),
            padding: const EdgeInsets.symmetric(vertical: 12),
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    source.name,
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      color: AppColors.deepInk,
                      height: 1.3,
                    ),
                  ),
                ),
                const SizedBox(width: 16),
                const Icon(
                  Icons.open_in_new,
                  color: AppColors.archivalCobalt,
                  size: 20,
                  semanticLabel: 'Opens externally',
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
