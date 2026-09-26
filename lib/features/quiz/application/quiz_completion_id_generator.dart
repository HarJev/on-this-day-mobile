import 'dart:math';

abstract interface class QuizCompletionIdGenerator {
  String nextId();
}

/// Generates opaque, collision-resistant IDs for locally frozen completions.
/// They are identifiers rather than a security boundary.
final class SecureQuizCompletionIdGenerator
    implements QuizCompletionIdGenerator {
  SecureQuizCompletionIdGenerator({Random? random})
    : _random = random ?? Random.secure();

  final Random _random;

  @override
  String nextId() {
    final bytes = List<int>.generate(16, (_) => _random.nextInt(256));
    return bytes.map((byte) => byte.toRadixString(16).padLeft(2, '0')).join();
  }
}
