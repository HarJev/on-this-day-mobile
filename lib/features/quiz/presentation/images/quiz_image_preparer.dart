import 'dart:async';
import 'dart:developer' as developer;
import 'dart:ui' as ui;
import '../../../../core/images/encoded_image_cache.dart';
import '../../domain/quiz_definition.dart';
import '../../domain/quiz_question.dart';
import '../quiz_session_preparation.dart';
import 'prepared_quiz_images.dart';
import 'quiz_image_decoder.dart';
import 'quiz_image_downloader.dart';
import 'quiz_image_preparation_exception.dart';

final class QuizImageLimits {
  QuizImageLimits({
    this.perImage = const Duration(seconds: 15),
    this.batch = const Duration(seconds: 60),
    this.encodedImage = 8 * 1024 * 1024,
    this.encodedSession = 32 * 1024 * 1024,
    this.decodedSession = 32 * 1024 * 1024,
    this.maxEdge = 1024,
  }) {
    if (perImage <= Duration.zero ||
        batch <= Duration.zero ||
        encodedImage <= 0 ||
        encodedSession <= 0 ||
        decodedSession <= 0 ||
        maxEdge <= 0 ||
        maxEdge > 1024) {
      throw ArgumentError(
        'Image limits must be positive; maxEdge must not exceed 1024',
      );
    }
  }
  final Duration perImage, batch;
  final int encodedImage, encodedSession, decodedSession, maxEdge;
}

final class QuizImagePreparer {
  QuizImagePreparer({
    required this.downloader,
    required this.decoder,
    QuizImageLimits? limits,
    this.cache,
    DateTime Function()? now,
    void Function(String message)? diagnostic,
  }) : limits = limits ?? QuizImageLimits(),
       _now = now ?? DateTime.now,
       _diagnostic = diagnostic ?? _defaultDiagnostic;
  final QuizImageDownloader downloader;
  final QuizImageDecoder decoder;
  final QuizImageLimits limits;
  final EncodedImageCache? cache;
  final DateTime Function() _now;
  final void Function(String message) _diagnostic;

  QuizPreparationAttempt call(QuizDefinition quiz) {
    final cancellation = QuizImageCancellation();
    return QuizPreparationAttempt(
      _prepare(quiz, cancellation),
      onCancel: cancellation.cancel,
    );
  }

  Future<QuizPreparedResources> _prepare(
    QuizDefinition quiz,
    QuizImageCancellation batch,
  ) async {
    final stopwatch = Stopwatch()..start();
    final batchDeadline = _now().add(limits.batch);
    final questions = {
      for (final q in quiz.questions.whereType<ImageIdentificationQuestion>())
        q.id: q.image.url,
    };
    final urls = questions.values.toSet().toList();
    final images = <Uri, ui.Image>{};
    final active = <QuizImageCancellation>{};
    var next = 0, encoded = 0, decoded = 0;
    final timer = Timer(
      limits.batch,
      () => batch.cancel(
        const QuizImagePreparationException(QuizImageFailure.timeout),
      ),
    );
    unawaited(
      batch.signal.then((_) {
        for (final token in active.toList()) {
          token.cancel();
        }
      }),
    );
    Future<void> worker() async {
      while (next < urls.length) {
        batch.check();
        final url = urls[next++];
        final token = QuizImageCancellation();
        final imageDeadline = _earlierDeadline(
          batchDeadline,
          _now().add(limits.perImage),
        );
        active.add(token);
        final timeout = Timer(
          limits.perImage,
          () => token.cancel(
            const QuizImagePreparationException(QuizImageFailure.timeout),
          ),
        );
        try {
          void reserveEncoded(int count) {
            token.check();
            batch.check();
            if (encoded + count > limits.encodedSession) {
              throw const QuizImagePreparationException(
                QuizImageFailure.encodedLimit,
              );
            }
            encoded += count;
          }

          var reserved = 0;
          void reserveDecoded(int count) {
            token.check();
            batch.check();
            if (count <= 0 || decoded + count > limits.decodedSession) {
              throw const QuizImagePreparationException(
                QuizImageFailure.decodedLimit,
              );
            }
            decoded += count;
            reserved += count;
          }

          final ui.Image image;
          if (cache case final cache?) {
            image = await token.wait(
              cache.load(
                url,
                token,
                maxBytes: limits.encodedImage,
                maxEdge: limits.maxEdge,
                download: (sharedCancellation) => downloader.download(
                  url,
                  sharedCancellation,
                  maxBytes: limits.encodedImage,
                  deadline: imageDeadline,
                  reserveBytes: (_) {},
                ),
                decode: decoder.decode,
                reserveEncodedBytes: reserveEncoded,
                reserveDecodedBytes: reserveDecoded,
              ),
            );
          } else {
            final bytes = await token.wait(
              downloader.download(
                url,
                token,
                maxBytes: limits.encodedImage,
                deadline: imageDeadline,
                reserveBytes: reserveEncoded,
              ),
            );
            final future = decoder
                .decode(
                  bytes,
                  token,
                  maxEdge: limits.maxEdge,
                  reserveDecodedBytes: reserveDecoded,
                )
                .then((image) {
                  if (token.isCancelled || batch.isCancelled) {
                    image.dispose();
                    token.check();
                    batch.check();
                  }
                  return image;
                });
            image = await token.wait(future);
          }
          if (image.width > limits.maxEdge ||
              image.height > limits.maxEdge ||
              image.width * image.height * 4 > reserved) {
            image.dispose();
            throw const QuizImagePreparationException(
              QuizImageFailure.decodedLimit,
            );
          }
          if (token.isCancelled || batch.isCancelled) {
            image.dispose();
            token.check();
            batch.check();
          }
          images[url] = image;
        } finally {
          timeout.cancel();
          active.remove(token);
          token.cancel();
        }
      }
    }

    try {
      await batch.wait(Future.wait([worker(), worker()], eagerError: true));
      batch.check();
      final prepared = PreparedQuizImages(questions, images);
      images.clear();
      _diagnostic(
        'image_preparation outcome=success images=${urls.length} '
        'durationMs=${stopwatch.elapsedMilliseconds}',
      );
      return QuizPreparedResources(() {}, images: prepared);
    } on ImageCacheException catch (error) {
      batch.cancel(error);
      for (final image in images.values) {
        image.dispose();
      }
      images.clear();
      final kind = switch (error.kind) {
        ImageCacheFailure.encodedLimit => QuizImageFailure.encodedLimit,
        ImageCacheFailure.decoding => QuizImageFailure.decoding,
        ImageCacheFailure.invalidRequest => QuizImageFailure.http,
      };
      throw QuizImagePreparationException(kind, cause: error.cause);
    } catch (error) {
      batch.cancel(error);
      for (final image in images.values) {
        image.dispose();
      }
      images.clear();
      final kind = error is QuizImagePreparationException
          ? error.kind.name
          : QuizImageFailure.http.name;
      _diagnostic(
        'image_preparation outcome=failure kind=$kind '
        'durationMs=${stopwatch.elapsedMilliseconds}',
      );
      if (error is QuizImagePreparationException) rethrow;
      throw QuizImagePreparationException(QuizImageFailure.http, cause: error);
    } finally {
      timer.cancel();
    }
  }

  static DateTime _earlierDeadline(DateTime first, DateTime second) =>
      first.isBefore(second) ? first : second;

  static void _defaultDiagnostic(String message) {
    developer.log(message, name: 'on_this_day.quiz_images');
  }
}
