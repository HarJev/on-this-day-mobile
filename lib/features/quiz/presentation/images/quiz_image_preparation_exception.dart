import 'dart:async';

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
final class QuizImageCancellation {
  final _signal = Completer<void>();
  Object? _reason;
  Future<void> get signal => _signal.future;
  bool get isCancelled => _signal.isCompleted;
  void cancel([
    Object reason = const QuizImagePreparationException(
      QuizImageFailure.cancelled,
    ),
  ]) {
    if (isCancelled) return;
    _reason = reason;
    _signal.complete();
  }

  void check() {
    if (isCancelled) throw _reason!;
  }

  Future<T> wait<T>(Future<T> work) =>
      Future.any([work, signal.then<T>((_) => throw _reason!)]);
}
