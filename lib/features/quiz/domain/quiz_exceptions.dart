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
