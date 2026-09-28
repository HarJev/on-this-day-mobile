import 'package:flutter/material.dart';

import '../../../../core/images/cached_optional_image_loader.dart';
import '../../../../core/config/app_colors.dart';
import '../../../../core/navigation/source_launcher.dart';
import '../../domain/event_image.dart';
import '../../domain/featured_event.dart';
import 'event_image_credit.dart';
import 'optional_event_image.dart';

class FeaturedEventCard extends StatelessWidget {
  const FeaturedEventCard({
    super.key,
    required this.event,
    required this.onTap,
    this.imageLoader,
    this.sourceLauncher = const PlatformSourceLauncher(),
  });

  final FeaturedEvent event;
  final VoidCallback onTap;
  final OptionalImageLoader? imageLoader;
  final SourceLauncher sourceLauncher;

  @override
  Widget build(BuildContext context) {
    final image = event.image;
    final loader = imageLoader;
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
            padding: const EdgeInsets.all(14),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (image != null && loader != null) ...[
                  _imageWithCredit(image, loader),
                ],
                Text(
                  event.year,
                  style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                    color: AppColors.archivalCobalt,
                    fontWeight: FontWeight.w500,
                    height: 1,
                  ),
                ),
                const SizedBox(height: 8),
                const Divider(color: AppColors.mutedCopper),
                const SizedBox(height: 14),
                Text(
                  event.title,
                  style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                    color: AppColors.deepInk,
                    fontFamily: 'Georgia',
                    fontFamilyFallback: const ['Times New Roman', 'serif'],
                    fontWeight: FontWeight.w700,
                    height: 1.1,
                  ),
                ),
                const SizedBox(height: 14),
                Text(
                  event.summary,
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: AppColors.deepInk,
                    fontWeight: FontWeight.w400,
                    height: 1.5,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _imageWithCredit(EventImage image, OptionalImageLoader loader) {
    final hasCredit = EventImageCredit.summaryFor(image) != null;
    return OptionalEventImage(
      url: image.url,
      altText: image.altText,
      loader: loader,
      // The credit row's own 48pt target supplies most of the gap.
      padding: EdgeInsets.only(bottom: hasCredit ? 8 : 22),
      caption: hasCredit
          ? EventImageCredit(image: image, launcher: sourceLauncher)
          : null,
    );
  }
}
