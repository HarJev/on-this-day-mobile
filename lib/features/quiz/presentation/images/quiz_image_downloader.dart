import 'dart:async';
import 'dart:typed_data';
import 'package:http/http.dart' as http;
import 'quiz_image_preparation_exception.dart';

abstract interface class QuizImageDownloader {
  Future<Uint8List> download(
    Uri url,
    QuizImageCancellation cancellation, {
    required int maxBytes,
    required void Function(int) reserveBytes,
  });
}

final class HttpQuizImageDownloader implements QuizImageDownloader {
  HttpQuizImageDownloader(this.client);
  final http.Client client;
  @override
  Future<Uint8List> download(
    Uri url,
    QuizImageCancellation cancellation, {
    required int maxBytes,
    required void Function(int) reserveBytes,
  }) async {
    cancellation.check();
    if (url.scheme != 'https') {
      throw const QuizImagePreparationException(QuizImageFailure.http);
    }
    final request =
        http.AbortableRequest('GET', url, abortTrigger: cancellation.signal)
          ..headers['accept'] = 'image/*'
          ..followRedirects = false;
    final bytes = BytesBuilder(copy: false);
    StreamSubscription<List<int>>? subscription;
    final done = Completer<void>();
    try {
      // Consume a late response even if an injected client ignores abort.
      final response = await cancellation.wait(
        client.send(request).then((response) {
          if (cancellation.isCancelled) {
            unawaited(response.stream.listen((_) {}).cancel());
            cancellation.check();
          }
          return response;
        }),
      );
      if (response.statusCode != 200 ||
          (response.contentLength ?? 0) > maxBytes) {
        await response.stream.listen((_) {}).cancel();
        throw QuizImagePreparationException(
          response.statusCode != 200
              ? QuizImageFailure.http
              : QuizImageFailure.encodedLimit,
        );
      }
      subscription = response.stream.listen(
        (chunk) {
          if (done.isCompleted || cancellation.isCancelled) return;
          try {
            if (bytes.length + chunk.length > maxBytes) {
              throw const QuizImagePreparationException(
                QuizImageFailure.encodedLimit,
              );
            }
            reserveBytes(chunk.length);
            bytes.add(chunk);
          } catch (error, stack) {
            done.completeError(error, stack);
          }
        },
        onError: (Object error, StackTrace stack) {
          if (!done.isCompleted) done.completeError(error, stack);
        },
        onDone: () {
          if (!done.isCompleted) done.complete();
        },
      );
      await cancellation.wait(done.future);
      cancellation.check();
      return bytes.takeBytes();
    } finally {
      // Subscription cancellation does not promise forced termination of a socket.
      if (subscription != null) unawaited(subscription.cancel());
      bytes.clear();
    }
  }
}
