import 'dart:async';

abstract interface class QuizSessionScheduler {
  /// Returns a cancellation callback. A cancelled callback may already be queued.
  void Function() schedule(void Function() tick);
}

final class TimerQuizSessionScheduler implements QuizSessionScheduler {
  @override
  void Function() schedule(void Function() tick) {
    final timer = Timer.periodic(
      const Duration(milliseconds: 100),
      (_) => tick(),
    );
    return timer.cancel;
  }
}
