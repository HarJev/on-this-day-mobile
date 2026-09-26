import 'dart:ui' as ui;

import 'package:flutter/material.dart';

import '../../../../core/images/cached_optional_image_loader.dart';
import '../../../../core/images/image_request_cancellation.dart';

/// History remains readable when an optional archival image is unavailable.
class OptionalEventImage extends StatefulWidget {
  const OptionalEventImage({
    super.key,
    required this.url,
    required this.altText,
    required this.loader,
    this.padding = EdgeInsets.zero,
  });

  final Uri url;
  final String altText;
  final OptionalImageLoader loader;
  final EdgeInsetsGeometry padding;

  @override
  State<OptionalEventImage> createState() => _OptionalEventImageState();
}

class _OptionalEventImageState extends State<OptionalEventImage> {
  ImageRequestCancellation? _cancellation;
  ui.Image? _image;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void didUpdateWidget(OptionalEventImage oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.url == widget.url && oldWidget.loader == widget.loader) {
      return;
    }
    _cancellation?.cancel();
    _image?.dispose();
    _image = null;
    _load();
  }

  Future<void> _load() async {
    final cancellation = ImageRequestCancellation();
    _cancellation = cancellation;
    try {
      final image = await widget.loader.load(widget.url, cancellation);
      if (!mounted || !identical(_cancellation, cancellation)) {
        image.dispose();
        return;
      }
      setState(() => _image = image);
    } catch (_) {
      if (mounted && identical(_cancellation, cancellation)) setState(() {});
    }
  }

  @override
  void dispose() {
    _cancellation?.cancel();
    _image?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final image = _image;
    if (image == null) return const SizedBox.shrink();
    return Semantics(
      image: true,
      label: widget.altText,
      child: ExcludeSemantics(
        child: Padding(
          padding: widget.padding,
          child: AspectRatio(
            aspectRatio: 2.05,
            child: RawImage(image: image, fit: BoxFit.cover),
          ),
        ),
      ),
    );
  }
}
