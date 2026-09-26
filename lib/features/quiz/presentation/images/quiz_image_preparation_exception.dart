import '../../../../core/images/image_request_cancellation.dart';

enum QuizImageFailure {
  cancelled,
  timeout,
  http,
  encodedLimit,
  decodedLimit,
  decoding,
  missing,
}

final class QuizImagePreparationException implements Exception {
  const QuizImagePreparationException(this.kind, {this.cause});
  final QuizImageFailure kind;
  final Object? cause;
  @override
  String toString() => 'Quiz image preparation failed: ${kind.name}';
}

/// Attempt-local cancellation; native decoder work may still finish later.
final class QuizImageCancellation extends ImageRequestCancellation {
  @override
  void cancel([
    Object? reason = const QuizImagePreparationException(
      QuizImageFailure.cancelled,
    ),
  ]) => super.cancel(reason);
}
