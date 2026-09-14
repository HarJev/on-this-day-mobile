class InvalidQuizDefinitionException implements Exception {
  const InvalidQuizDefinitionException(this.message);
  final String message;
  @override
  String toString() => 'InvalidQuizDefinitionException: $message';
}

enum QuizFailureKind {
  unavailable,
  invalidSelection,
  invalidTimezone,
  invalidContent,
  request,
  storage,
}

class QuizException implements Exception {
  const QuizException(this.kind, this.message, {this.cause});
  final QuizFailureKind kind;
  final String message;
  final Object? cause;
}

/// A local-result persistence failure. Callers must distinguish this from a
/// missing result so a corrupted database is never presented as an empty one.
class QuizStorageException extends QuizException {
  const QuizStorageException(String message, {Object? cause})
    : super(QuizFailureKind.storage, message, cause: cause);
}

/// A completion ID is immutable once a durable receipt exists.
final class QuizCompletionConflictException extends QuizStorageException {
  const QuizCompletionConflictException(super.message, {super.cause});
}

/// A durable row was readable but failed its consistency checks.
final class QuizStorageCorruptionException extends QuizStorageException {
  const QuizStorageCorruptionException(super.message, {super.cause});
}
