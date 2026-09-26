import 'dart:math' as math;
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'image_request_cancellation.dart';

abstract interface class ImageDecoder {
  Future<ui.Image> decode(
    Uint8List bytes,
    ImageRequestCancellation cancellation, {
    required int maxEdge,
    required void Function(int) reserveDecodedBytes,
  });
}

final class FlutterImageDecoder implements ImageDecoder {
  @override
  Future<ui.Image> decode(
    Uint8List bytes,
    ImageRequestCancellation cancellation, {
    required int maxEdge,
    required void Function(int) reserveDecodedBytes,
  }) async {
    ui.ImmutableBuffer? buffer;
    ui.ImageDescriptor? descriptor;
    ui.Codec? codec;
    ui.Image? image;
    try {
      cancellation.check();
      buffer = await ui.ImmutableBuffer.fromUint8List(bytes);
      cancellation.check();
      descriptor = await ui.ImageDescriptor.encoded(buffer);
      cancellation.check();
      final scale = math.min(
        1.0,
        maxEdge / math.max(descriptor.width, descriptor.height),
      );
      final width = math.max(1, (descriptor.width * scale).floor());
      final height = math.max(1, (descriptor.height * scale).floor());
      reserveDecodedBytes(width * height * 4);
      codec = await descriptor.instantiateCodec(
        targetWidth: width,
        targetHeight: height,
      );
      cancellation.check();
      image = (await codec.getNextFrame()).image;
      cancellation.check();
      if (image.width > width ||
          image.height > height ||
          codec.frameCount != 1) {
        throw const ImageDecodeException();
      }
      final result = image;
      image = null;
      return result;
    } on ImageDecodeException {
      rethrow;
    } catch (error) {
      throw ImageDecodeException(cause: error);
    } finally {
      image?.dispose();
      codec?.dispose();
      descriptor?.dispose();
      buffer?.dispose();
    }
  }
}

final class ImageDecodeException implements Exception {
  const ImageDecodeException({this.cause});

  final Object? cause;
}
