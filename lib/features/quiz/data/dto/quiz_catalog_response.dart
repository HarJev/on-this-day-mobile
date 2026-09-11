import '../../domain/quiz_catalog.dart';
import '../../domain/quiz_rules.dart';
import 'quiz_json.dart';

final class QuizCatalogResponse {
  QuizCatalogResponse.fromJson(Map<String, Object?> value) {
    final json = QuizJson(value);
    final counts = json.integers('questionCounts');
    if (counts.length != QuizRules.questionCounts.length ||
        counts.toSet().length != counts.length ||
        !counts.toSet().containsAll(QuizRules.questionCounts)) {
      json.invalid('questionCounts', 'supported quiz counts');
    }
    mixed = _availability(json.object('mixed'));
    collections = List.unmodifiable(
      json
          .objects('collections')
          .map(
            (c) => QuizCollection(
              id: c.string('id'),
              name: c.string('name'),
              group: c.enumValue('group', const {
                'topic': QuizCollectionGroup.topic,
                'historical_period': QuizCollectionGroup.historicalPeriod,
                'civilization': QuizCollectionGroup.civilization,
                'conflict_or_movement': QuizCollectionGroup.conflictOrMovement,
              }),
              availability: _availability(c),
            ),
          ),
    );
    final timers = json.object('quickPlayTimerDefaultsSeconds');
    timerDefaults = Map.unmodifiable({
      QuizQuestionType.multipleChoice: timers.duration('multipleChoice'),
      QuizQuestionType.trueFalse: timers.duration('trueFalse'),
      QuizQuestionType.imageIdentification: timers.duration(
        'imageIdentification',
      ),
      QuizQuestionType.chronologicalOrdering: timers.duration(
        'chronologicalOrdering',
      ),
    });
  }
  late final QuizAvailability mixed;
  late final List<QuizCollection> collections;
  late final Map<QuizQuestionType, Duration> timerDefaults;

  static QuizAvailability _availability(QuizJson json) => QuizAvailability(
    publishedQuestionCount: json.integer('publishedQuestionCount'),
    supportedQuestionCounts: json.integers('supportedQuestionCounts'),
  );

  QuizCatalog toDomain() => QuizCatalog(
    mixed: mixed,
    collections: collections,
    quickPlayTimerDefaults: timerDefaults,
  );
}
