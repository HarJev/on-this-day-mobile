import 'dart:typed_data';

import 'package:http/http.dart' as http;

import '../../../../core/images/image_downloader.dart';
import '../../../../core/images/image_request_cancellation.dart';
import 'quiz_image_preparation_exception.dart';

abstract interface class QuizImageDownloader {
  Future<Uint8List> download(
    Uri url,
    ImageRequestCancellation cancellation, {
    required int maxBytes,
    required void Function(int) reserveBytes,
    DateTime? deadline,
  });
}

/// Quiz compatibility wrapper around the shared L1 image transport.
final class HttpQuizImageDownloader implements QuizImageDownloader {
  HttpQuizImageDownloader(
    http.Client client, {
    QuizImageRetryPolicy? retryPolicy,
    DateTime Function()? now,
    void Function(String message)? diagnostic,
  }) : _delegate = HttpImageDownloader(
         client,
         retryPolicy: retryPolicy,
         now: now,
         diagnostic: diagnostic,
       );

  HttpQuizImageDownloader.fromDelegate(this._delegate);

  final HttpImageDownloader _delegate;

  @override
  Future<Uint8List> download(
    Uri url,
    ImageRequestCancellation cancellation, {
    required int maxBytes,
    required void Function(int) reserveBytes,
    DateTime? deadline,
  }) async {
    try {
      return await _delegate.download(
        url,
        cancellation,
        maxBytes: maxBytes,
        reserveBytes: reserveBytes,
        deadline: deadline,
      );
    } on ImageDownloadException catch (error) {
      throw QuizImagePreparationException(switch (error.kind) {
        ImageDownloadFailure.timeout => QuizImageFailure.timeout,
        ImageDownloadFailure.encodedLimit => QuizImageFailure.encodedLimit,
        ImageDownloadFailure.cancelled => QuizImageFailure.cancelled,
        ImageDownloadFailure.http => QuizImageFailure.http,
      }, cause: error.cause);
    } on ImageRequestCancelledException {
      throw const QuizImagePreparationException(QuizImageFailure.cancelled);
    }
  }
}

typedef QuizImageRetryPolicy = ImageRetryPolicy;
