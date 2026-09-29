import 'quiz_validation.dart';

/// Explicit editorial relationship, displayed only after quiz completion.
final class QuizRelatedEvent {
  QuizRelatedEvent({
    required this.id,
    required this.title,
    required this.year,
  }) {
    requireId(id);
    requireText(title);
    requireText(year);
  }

  final String id, title, year;
}
