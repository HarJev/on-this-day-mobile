import 'dart:math' as math;
import 'dart:typed_data';
import 'dart:ui' as ui;
import 'quiz_image_preparation_exception.dart';

abstract interface class QuizImageDecoder {
  Future<ui.Image> decode(
    Uint8List bytes,
    QuizImageCancellation cancellation, {
    required int maxEdge,
    required void Function(int) reserveDecodedBytes,
  });
}

final class FlutterQuizImageDecoder implements QuizImageDecoder {
  @override
  Future<ui.Image> decode(
    Uint8List bytes,
    QuizImageCancellation cancellation, {
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
        throw const QuizImagePreparationException(QuizImageFailure.decoding);
      }
      final result = image;
      image = null;
      return result;
    } on QuizImagePreparationException {
      rethrow;
    } catch (error) {
      throw QuizImagePreparationException(
        QuizImageFailure.decoding,
        cause: error,
      );
    } finally {
      image?.dispose();
      codec?.dispose();
      descriptor?.dispose();
      buffer?.dispose();
    }
  }
}
