import 'package:flutter/material.dart';

import '../../../../core/config/app_colors.dart';
import '../../../../core/navigation/source_launcher.dart';
import '../../domain/event_image.dart';
import '../../domain/event_source.dart';
import 'source_row.dart';

/// A quiet one-line credit under an event image. The full credit, with the
/// source page and licence links, sits behind one tap in a bottom sheet so
/// provenance stays reachable without competing with the story.
class EventImageCredit extends StatelessWidget {
  const EventImageCredit({
    super.key,
    required this.image,
    required this.launcher,
  });

  final EventImage image;
  final SourceLauncher launcher;

  /// Returns null when the image carries nothing worth crediting.
  static String? summaryFor(EventImage image) {
    final who = _firstText([image.creator, image.attribution, image.source]);
    final parts = [?who, ?_text(image.license)];
    if (parts.isEmpty) return null;
    return 'Image: ${parts.join(' · ')}';
  }

  @override
  Widget build(BuildContext context) {
    final summary = summaryFor(image);
    if (summary == null) return const SizedBox.shrink();
    return Semantics(
      button: true,
      container: true,
      label: '$summary. Show image credit',
      excludeSemantics: true,
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          key: const Key('event-image-credit'),
          onTap: () => _showDetails(context),
          child: ConstrainedBox(
            constraints: const BoxConstraints(minHeight: 48),
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    summary,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: Theme.of(context).textTheme.labelSmall?.copyWith(
                      color: AppColors.mutedGray,
                      fontWeight: FontWeight.w400,
                      height: 1.4,
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                const Icon(
                  Icons.info_outline,
                  size: 14,
                  color: AppColors.mutedGray,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Future<void> _showDetails(BuildContext context) {
    return showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      builder: (sheetContext) => _CreditDetails(
        image: image,
        onOpen: (url) => _open(sheetContext, url),
      ),
    );
  }

  Future<void> _open(BuildContext context, Uri url) async {
    final opened = await launcher.open(url);
    if (!opened && context.mounted) {
      ScaffoldMessenger.maybeOf(
        context,
      )?.showSnackBar(const SnackBar(content: Text('Could not open link.')));
    }
  }
}

class _CreditDetails extends StatelessWidget {
  const _CreditDetails({required this.image, required this.onOpen});

  final EventImage image;
  final ValueChanged<Uri> onOpen;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    final creator = _text(image.creator);
    final attribution = _text(image.attribution);
    final source = _text(image.source);
    final license = _text(image.license);
    final sourceUrl = image.sourceUrl;
    final licenseUrl = image.licenseUrl;
    return SafeArea(
      top: false,
      child: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(20, 0, 20, 24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Semantics(
              header: true,
              child: Text(
                'Image credit',
                style: textTheme.titleLarge,
              ),
            ),
            const SizedBox(height: 12),
            if (attribution != null) _DetailText(attribution),
            if (creator != null && creator != attribution)
              _DetailText('Creator: $creator'),
            if (source != null && sourceUrl == null)
              _DetailText('Source: $source'),
            if (license != null && licenseUrl == null)
              _DetailText('Licence: $license'),
            const SizedBox(height: 8),
            if (sourceUrl != null)
              SourceRow(
                source: EventSource(
                  name: source ?? 'Image source',
                  url: sourceUrl,
                ),
                onTap: () => onOpen(sourceUrl),
              ),
            if (licenseUrl != null)
              SourceRow(
                source: EventSource(
                  name: license ?? 'Image licence',
                  url: licenseUrl,
                ),
                onTap: () => onOpen(licenseUrl),
              ),
          ],
        ),
      ),
    );
  }
}

class _DetailText extends StatelessWidget {
  const _DetailText(this.text);

  final String text;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Text(
        text,
        style: Theme.of(context).textTheme.bodyMedium,
      ),
    );
  }
}

String? _text(String? value) {
  final trimmed = value?.trim();
  return trimmed == null || trimmed.isEmpty ? null : trimmed;
}

String? _firstText(List<String?> values) {
  for (final value in values) {
    final text = _text(value);
    if (text != null) return text;
  }
  return null;
}
