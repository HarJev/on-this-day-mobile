import 'dart:async';

/// A request-local cancellation signal for bounded image work.
class ImageRequestCancellation {
  final _signal = Completer<void>();
  Object? _reason;

  Future<void> get signal => _signal.future;
  bool get isCancelled => _signal.isCompleted;

  void cancel([Object? reason]) {
    if (isCancelled) return;
    _reason = reason ?? const ImageRequestCancelledException();
    _signal.complete();
  }

  void check() {
    if (isCancelled) throw _reason!;
  }

  Future<T> wait<T>(Future<T> work) =>
      Future.any([work, signal.then<T>((_) => throw _reason!)]);
}

final class ImageRequestCancelledException implements Exception {
  const ImageRequestCancelledException();
}
