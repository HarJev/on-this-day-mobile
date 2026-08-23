import 'package:flutter/material.dart';

import '../../../../core/config/app_colors.dart';
import '../../domain/featured_event.dart';

class FeaturedEventCard extends StatelessWidget {
  const FeaturedEventCard({
    super.key,
    required this.event,
    required this.onTap,
  });

  final FeaturedEvent event;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      label: event.title,
      child: Material(
        color: AppColors.softIvory,
        shape: RoundedRectangleBorder(
          side: const BorderSide(color: AppColors.paleStone),
          borderRadius: BorderRadius.circular(2),
        ),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (event.image case final image?) ...[
                  AspectRatio(
                    aspectRatio: 1.55,
                    child: Image.network(
                      image.url.toString(),
                      fit: BoxFit.cover,
                      semanticLabel: image.altText,
                    ),
                  ),
                  const SizedBox(height: 52),
                ],
                Text(
                  event.year,
                  style: Theme.of(context).textTheme.displaySmall?.copyWith(
                    color: AppColors.archivalCobalt,
                    fontWeight: FontWeight.w500,
                    height: 1,
                  ),
                ),
                const SizedBox(height: 14),
                const Divider(color: AppColors.mutedCopper),
                const SizedBox(height: 24),
                Text(
                  event.title,
                  style: Theme.of(context).textTheme.displaySmall?.copyWith(
                    color: AppColors.deepInk,
                    fontWeight: FontWeight.w800,
                    height: 1.12,
                  ),
                ),
                const SizedBox(height: 26),
                Text(
                  event.summary,
                  style: Theme.of(context).textTheme.titleLarge?.copyWith(
                    color: AppColors.deepInk,
                    fontWeight: FontWeight.w400,
                    height: 1.45,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
