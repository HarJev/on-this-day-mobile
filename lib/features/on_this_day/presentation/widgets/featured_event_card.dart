import 'package:flutter/material.dart';

import '../../../../core/config/app_colors.dart';
import '../../../../core/images/cached_optional_image_loader.dart';
import '../../../../core/navigation/source_launcher.dart';
import '../../domain/event_image.dart';
import '../../domain/featured_event.dart';
import 'event_image_credit.dart';
import 'optional_event_image.dart';

/// The day's editorial pick: the strongest element on Today.
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
    final hasImage = image != null && loader != null;
    final textTheme = Theme.of(context).textTheme;
    return Semantics(
      button: true,
      label: event.title,
      child: Material(
        color: AppColors.softIvory,
        shape: RoundedRectangleBorder(
          side: const BorderSide(color: AppColors.paleStone),
          borderRadius: BorderRadius.circular(16),
        ),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: onTap,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              if (hasImage) _imageWithCredit(image, loader),
              Padding(
                padding: EdgeInsets.fromLTRB(20, hasImage ? 18 : 22, 20, 20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      event.year,
                      style:
                          (hasImage
                                  ? textTheme.displayMedium
                                  : textTheme.displayMedium?.copyWith(
                                      fontSize: 56,
                                    ))
                              ?.copyWith(color: AppColors.archivalCobalt),
                    ),
                    const SizedBox(height: 10),
                    const Divider(color: Color(0x8CA66A3F)),
                    const SizedBox(height: 12),
                    Text(
                      event.title,
                      style: textTheme.headlineMedium?.copyWith(
                        fontSize: hasImage ? 28 : 30,
                      ),
                    ),
                    const SizedBox(height: 10),
                    Text(
                      event.summary,
                      style: textTheme.bodyLarge?.copyWith(
                        color: AppColors.bodySoft,
                      ),
                    ),
                    const SizedBox(height: 10),
                    ExcludeSemantics(
                      child: ConstrainedBox(
                        constraints: const BoxConstraints(minHeight: 40),
                        child: Row(
                          children: [
                            Flexible(
                              child: Text(
                                'Read the full story',
                                style: textTheme.titleSmall?.copyWith(
                                  color: AppColors.archivalCobalt,
                                ),
                              ),
                            ),
                            const SizedBox(width: 6),
                            const Icon(
                              Icons.arrow_forward,
                              size: 18,
                              color: AppColors.archivalCobalt,
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
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
      aspectRatio: 16 / 9.5,
      caption: hasCredit
          ? Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: EventImageCredit(image: image, launcher: sourceLauncher),
            )
          : null,
    );
  }
}
