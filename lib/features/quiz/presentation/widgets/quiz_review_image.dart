import 'dart:ui' as ui;

import 'package:flutter/material.dart';

import '../../../../core/config/app_colors.dart';
import '../../../../core/images/cached_optional_image_loader.dart';
import '../../../../core/images/image_request_cancellation.dart';
import '../../domain/quiz_image.dart';

/// Shows a picture question's image in Review. The question is already
/// answered, so the image is loaded on demand through the shared disk cache
/// that gameplay filled. Nothing is shown while it loads; a failed load keeps
/// the plain unavailable message so the recorded result reads the same.
final class QuizReviewImage extends StatefulWidget {
  const QuizReviewImage({super.key, required this.image, this.loader});

  final QuizImage image;
  final OptionalImageLoader? loader;

  static const unavailableMessage = 'Image unavailable in review.';

  @override
  State<QuizReviewImage> createState() => _QuizReviewImageState();
}

class _QuizReviewImageState extends State<QuizReviewImage> {
  ImageRequestCancellation? _cancellation;
  ui.Image? _picture;
  var _failed = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void didUpdateWidget(QuizReviewImage oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.image.url == widget.image.url &&
        oldWidget.loader == widget.loader) {
      return;
    }
    _cancellation?.cancel();
    _picture?.dispose();
    _picture = null;
    _failed = false;
    _load();
  }

  Future<void> _load() async {
    final loader = widget.loader;
    if (loader == null) {
      _failed = true;
      return;
    }
    final cancellation = ImageRequestCancellation();
    _cancellation = cancellation;
    try {
      final picture = await loader.load(widget.image.url, cancellation);
      if (!mounted || !identical(_cancellation, cancellation)) {
        picture.dispose();
        return;
      }
      setState(() => _picture = picture);
    } catch (_) {
      if (mounted && identical(_cancellation, cancellation)) {
        setState(() => _failed = true);
      }
    }
  }

  @override
  void dispose() {
    _cancellation?.cancel();
    _picture?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final picture = _picture;
    if (picture == null) {
      if (!_failed) return const SizedBox.shrink();
      return Padding(
        padding: const EdgeInsets.only(bottom: 8),
        child: Semantics(
          image: true,
          label: widget.image.altText,
          child: Text(
            QuizReviewImage.unavailableMessage,
            style: Theme.of(context).textTheme.bodySmall,
          ),
        ),
      );
    }
    final maxHeight = (MediaQuery.sizeOf(context).height * 0.28).clamp(
      150.0,
      250.0,
    );
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Semantics(
        image: true,
        label: widget.image.altText,
        child: ExcludeSemantics(
          // Matches the gameplay mat so portraits stay uncropped.
          child: DecoratedBox(
            decoration: BoxDecoration(
              color: AppColors.softIvory,
              border: Border.all(color: AppColors.paleStone),
              borderRadius: BorderRadius.circular(6),
            ),
            child: Padding(
              padding: const EdgeInsets.all(8),
              child: Center(
                child: ConstrainedBox(
                  constraints: BoxConstraints(maxHeight: maxHeight),
                  child: AspectRatio(
                    aspectRatio: picture.width / picture.height,
                    child: RawImage(image: picture, fit: BoxFit.contain),
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
