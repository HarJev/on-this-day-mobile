import 'quiz_exceptions.dart';

void requireQuiz(bool condition, String message) {
  if (!condition) throw InvalidQuizDefinitionException(message);
}

void requireText(String value) =>
    requireQuiz(value.trim().isNotEmpty, 'Text must not be blank');
void requireId(String value) => requireQuiz(
  RegExp(r'^[a-z0-9]+(?:-[a-z0-9]+)*$').hasMatch(value),
  'Invalid ID: $value',
);
void requireHttps(Uri value) => requireQuiz(
  value.scheme == 'https' && value.host.isNotEmpty && value.userInfo.isEmpty,
  'Expected absolute HTTPS URL',
);
void requirePermutation(List<String> actual, Iterable<String> expected) {
  final ids = expected.toSet();
  requireQuiz(
    actual.length == ids.length &&
        actual.toSet().length == actual.length &&
        ids.containsAll(actual),
    'Invalid ID permutation',
  );
}
