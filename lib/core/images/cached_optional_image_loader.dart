import 'dart:async';
import 'dart:ui' as ui;

import 'encoded_image_cache.dart';
import 'flutter_image_decoder.dart';
import 'image_downloader.dart';
import 'image_request_cancellation.dart';

abstract interface class OptionalImageLoader {
  Future<ui.Image> load(Uri url, ImageRequestCancellation cancellation);
}

/// Loads optional editorial images through the same bounded cache and L1 path.
final class CachedOptionalImageLoader implements OptionalImageLoader {
  CachedOptionalImageLoader({
    required this.cache,
    required this.downloader,
    ImageDecoder? decoder,
    this.perImageTimeout = const Duration(seconds: 15),
  }) : _decoder = decoder ?? FlutterImageDecoder() {
    if (perImageTimeout <= Duration.zero) {
      throw ArgumentError.value(
        perImageTimeout,
        'perImageTimeout',
        'Must be positive',
      );
    }
  }

  static const maxEncodedBytes = 8 * 1024 * 1024;
  static const maxEdge = 1024;

  final EncodedImageCache cache;
  final ImageByteDownloader downloader;
  final Duration perImageTimeout;
  final ImageDecoder _decoder;

  @override
  Future<ui.Image> load(Uri url, ImageRequestCancellation cancellation) async {
    final requestCancellation = ImageRequestCancellation();
    unawaited(
      cancellation.signal.then<void>((_) => requestCancellation.cancel()),
    );
    final deadline = DateTime.now().add(perImageTimeout);
    final timeout = Timer(
      perImageTimeout,
      () => requestCancellation.cancel(
        const ImageDownloadException(ImageDownloadFailure.timeout),
      ),
    );
    try {
      return await cache.load(
        url,
        requestCancellation,
        maxBytes: maxEncodedBytes,
        maxEdge: maxEdge,
        download: (sharedCancellation) => downloader.download(
          url,
          sharedCancellation,
          maxBytes: maxEncodedBytes,
          reserveBytes: (_) {},
          deadline: deadline,
        ),
        decode: _decoder.decode,
        reserveEncodedBytes: (_) {},
        reserveDecodedBytes: (_) {},
      );
    } finally {
      timeout.cancel();
      requestCancellation.cancel();
    }
  }

  Future<void> invalidate(Uri url) => cache.invalidate(url);
}
