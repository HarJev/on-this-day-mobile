abstract interface class QuizSessionClock {
  Duration get elapsed;
  DateTime get utcNow;
}

final class StopwatchQuizSessionClock implements QuizSessionClock {
  final Stopwatch _stopwatch = Stopwatch()..start();
  @override
  Duration get elapsed => _stopwatch.elapsed;
  @override
  DateTime get utcNow => DateTime.now().toUtc();
}
