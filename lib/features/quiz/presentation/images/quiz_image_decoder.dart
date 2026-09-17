import 'dart:typed_data';
import 'dart:ui' as ui;

import '../../../../core/images/flutter_image_decoder.dart';
import '../../../../core/images/image_request_cancellation.dart';
import 'quiz_image_preparation_exception.dart';

abstract interface class QuizImageDecoder {
  Future<ui.Image> decode(
    Uint8List bytes,
    ImageRequestCancellation cancellation, {
    required int maxEdge,
    required void Function(int) reserveDecodedBytes,
  });
}

final class FlutterQuizImageDecoder implements QuizImageDecoder {
  FlutterQuizImageDecoder({ImageDecoder? delegate})
    : _delegate = delegate ?? FlutterImageDecoder();

  final ImageDecoder _delegate;

  @override
  Future<ui.Image> decode(
    Uint8List bytes,
    ImageRequestCancellation cancellation, {
    required int maxEdge,
    required void Function(int) reserveDecodedBytes,
  }) async {
    try {
      return await _delegate.decode(
        bytes,
        cancellation,
        maxEdge: maxEdge,
        reserveDecodedBytes: reserveDecodedBytes,
      );
    } on ImageDecodeException catch (error) {
      throw QuizImagePreparationException(
        QuizImageFailure.decoding,
        cause: error.cause,
      );
    }
  }
}
