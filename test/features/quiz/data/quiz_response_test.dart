import 'package:flutter_test/flutter_test.dart';
import 'package:on_this_day_mobile/features/quiz/data/dto/daily_quiz_response.dart';
import 'package:on_this_day_mobile/features/quiz/data/dto/quick_play_response.dart';
import 'package:on_this_day_mobile/features/quiz/data/dto/quiz_catalog_response.dart';
import 'package:on_this_day_mobile/features/quiz/domain/quiz_exceptions.dart';
import 'package:on_this_day_mobile/features/quiz/domain/quiz_question.dart';
import 'package:on_this_day_mobile/features/quiz/domain/quiz_rules.dart';

import 'quiz_api_fixtures.dart';

final invalid = throwsA(
  anyOf(isA<FormatException>(), isA<InvalidQuizDefinitionException>()),
);

void main() {
  test('selection requires explicit nullable collection identity', () {
    final json = quickJson();
    objectAt(json, 'selection').remove('collectionId');
    expect(() => QuickPlayResponse.fromJson(json).toDomain(), invalid);
  });
  test('response DTOs do not retain mutable JSON lists', () {
    final json = quickJson();
    final dto = QuickPlayResponse.fromJson(json);
    objectsAt(json, 'questions').first['prompt'] = 'Changed';
    objectsAt(objectsAt(json, 'questions')[0], 'options').first['id'] =
        'changed';
    final quiz = dto.toDomain();
    expect(quiz.questions.first.prompt, 'Question 0?');
    expect((quiz.questions.first as ChoiceQuestion).options.first.id, 'c');
    expect(() => dto.questions.clear(), throwsUnsupportedError);
  });
  test(
    'all types preserve presentation order and separate correct answers',
    () {
      final q = QuickPlayResponse.fromJson(quickJson()).toDomain();
      expect(
        q.questions.map((v) => v.id),
        List.generate(5, (i) => 'question-$i'),
      );
      expect(q.questions.map((v) => v.type), [
        QuizQuestionType.multipleChoice,
        QuizQuestionType.trueFalse,
        QuizQuestionType.imageIdentification,
        QuizQuestionType.chronologicalOrdering,
        QuizQuestionType.multipleChoice,
      ]);
      final choice = q.questions[0] as MultipleChoiceQuestion;
      expect(choice.options.map((v) => v.id), ['c', 'a', 'd', 'b']);
      expect(choice.correctOptionId, 'a');
      expect(choice.difficulty, QuizDifficulty.easy);
      expect(choice.prompt, 'Question 0?');
      expect(choice.explanation, 'Explanation 0.');
      expect((q.questions[1] as TrueFalseQuestion).options.map((v) => v.text), [
        'True',
        'False',
      ]);
      final order = q.questions[3] as ChronologicalOrderingQuestion;
      expect(order.items.map((v) => v.id), ['d', 'b', 'a', 'c']);
      expect(order.correctOrderItemIds, ['a', 'b', 'c', 'd']);
      expect(q.questionTimeLimits.values.map((v) => v.inSeconds), [
        20,
        20,
        30,
        45,
        20,
      ]);
    },
  );
  test('image and sources preserve complete provenance', () {
    final q =
        QuickPlayResponse.fromJson(quickJson()).toDomain().questions[2]
            as ImageIdentificationQuestion;
    expect(q.sources.single.displayName, 'Museum');
    expect(q.sources.single.url, Uri.parse('https://example.org/source'));
    expect(q.image.url, Uri.parse('https://example.org/image.jpg'));
    expect(q.image.altText, 'An archival object');
    expect(q.image.source, 'Museum');
    expect(q.image.sourceUrl, Uri.parse('https://example.org/collection'));
    expect(q.image.attribution, 'Museum collection');
    expect(q.image.creator, 'An artist');
    expect(q.image.license, 'CC0');
    expect(q.image.licenseUrl, Uri.parse('https://example.org/license'));
  });
  for (final omit in [true, false]) {
    test('creator ${omit ? 'omitted' : 'null'} is accepted', () {
      final json = quickJson();
      final image = objectAt(objectsAt(json, 'questions')[2], 'image');
      if (omit) {
        image.remove('creator');
      } else {
        image['creator'] = null;
      }
      final q =
          QuickPlayResponse.fromJson(json).toDomain().questions[2]
              as ImageIdentificationQuestion;
      expect(q.image.creator, isNull);
    });
  }
  for (final count in [5, 10, 20]) {
    test('Daily $count uses backend metadata without per-question timers', () {
      final q = DailyQuizResponse.fromJson(dailyJson(count: count)).toDomain();
      expect(q.questionCount, count);
      expect(q.assignmentQuestionCount, 20);
      expect(q.duration, QuizRules.dailyDefaults[count]);
      expect(q.date.isoDate, '2026-08-24');
      expect(q.displayDate, 'Aug 24');
    });
  }
  test(
    'arbitrary positive backend durations and false default are preserved',
    () {
      final daily = dailyJson();
      objectAt(daily, 'timer')['durationSeconds'] = 17;
      expect(
        DailyQuizResponse.fromJson(daily).toDomain().duration.inSeconds,
        17,
      );
      final quick = quickJson();
      objectAt(quick, 'timer')['enabledByDefault'] = false;
      objectsAt(quick, 'questions').first['timeLimitSeconds'] = 9;
      final q = QuickPlayResponse.fromJson(quick).toDomain();
      expect(q.timingEnabledByDefault, isFalse);
      expect(q.questionTimeLimits['question-0']!.inSeconds, 9);
    },
  );
  test('unknown additive fields are ignored at every level', () {
    final json = quickJson()..['futureField'] = 'ignored';
    objectAt(json, 'timer')['futureTimer'] = 1;
    objectAt(json, 'selection')['futureSelection'] = true;
    for (final q in objectsAt(json, 'questions')) {
      q['futureQuestion'] = [];
      objectsAt(q, 'sources').first['futureSource'] = null;
    }
    objectAt(objectsAt(json, 'questions')[2], 'image')['futureImage'] = 'extra';
    expect(QuickPlayResponse.fromJson(json).toDomain().questionCount, 5);
  });
  final questionMutations = <String, void Function(Map<String, Object?>)>{
    'missing prompt': (q) => q.remove('prompt'),
    'null prompt': (q) => q['prompt'] = null,
    'blank explanation': (q) => q['explanation'] = ' ',
    'numeric prompt': (q) => q['prompt'] = 7,
    'bad ID': (q) => q['id'] = 'Not a slug',
    'unknown type': (q) => q['type'] = 'essay',
    'unknown difficulty': (q) => q['difficulty'] = 'expert',
    'missing sources': (q) => q.remove('sources'),
    'empty sources': (q) => q['sources'] = [],
    'source wrong type': (q) => q['sources'] = ['not an object'],
    'source name instead of displayName': (q) =>
        objectsAt(q, 'sources').first.remove('displayName'),
    'HTTP source': (q) =>
        objectsAt(q, 'sources').first['url'] = 'http://example.org',
    'relative source': (q) => objectsAt(q, 'sources').first['url'] = '/source',
    'duplicate sources': (q) => q['sources'] = [
      objectsAt(q, 'sources').first,
      objectsAt(q, 'sources').first,
    ],
    'three options': (q) =>
        q['options'] = objectsAt(q, 'options').take(3).toList(),
    'duplicate options': (q) => objectsAt(q, 'options')[1]['id'] = 'c',
    'unknown answer': (q) => q['correctOptionId'] = 'missing',
    'null answer': (q) => q['correctOptionId'] = null,
    'blank option text': (q) => objectsAt(q, 'options').first['text'] = ' ',
    'missing timer': (q) => q.remove('timeLimitSeconds'),
    'null timer': (q) => q['timeLimitSeconds'] = null,
    'zero timer': (q) => q['timeLimitSeconds'] = 0,
    'negative timer': (q) => q['timeLimitSeconds'] = -1,
    'decimal timer': (q) => q['timeLimitSeconds'] = 20.0,
    'string timer': (q) => q['timeLimitSeconds'] = '20',
    'image on text question': (q) => q['image'] = imageJson(),
    'ordering field on choice': (q) => q['items'] = [],
    'ordering answer on choice': (q) => q['correctOrderItemIds'] = [],
  };
  for (final entry in questionMutations.entries) {
    test('rejects ${entry.key}', () {
      final json = quickJson();
      entry.value(objectsAt(json, 'questions').first);
      expect(() => QuickPlayResponse.fromJson(json).toDomain(), invalid);
    });
  }
  final envelopeMutations = <String, void Function(Map<String, Object?>)>{
    'wrong mode': (j) => j['mode'] = 'daily',
    'wrong timer mode': (j) => objectAt(j, 'timer')['mode'] = 'total',
    'string enabled': (j) => objectAt(j, 'timer')['enabledByDefault'] = 'true',
    'missing enabled': (j) => objectAt(j, 'timer').remove('enabledByDefault'),
    'conflicting total timer': (j) =>
        objectAt(j, 'timer')['durationSeconds'] = 120,
    'missing count': (j) => j.remove('questionCount'),
    'floating count': (j) => j['questionCount'] = 5.0,
    'wrong list count': (j) => j['questionCount'] = 10,
    'duplicate question': (j) =>
        objectsAt(j, 'questions')[1]['id'] = 'question-0',
    'missing selection': (j) => j.remove('selection'),
    'blank collection': (j) => objectAt(j, 'selection')['collectionId'] = '',
    'missing image': (j) => objectsAt(j, 'questions')[2].remove('image'),
    'blank creator': (j) =>
        objectAt(objectsAt(j, 'questions')[2], 'image')['creator'] = ' ',
    'true false reversed': (j) {
      final q = objectsAt(j, 'questions')[1];
      q['options'] = objectsAt(q, 'options').reversed.toList();
    },
    'true false wrong labels': (j) =>
        objectsAt(objectsAt(j, 'questions')[1], 'options').first['text'] =
            'Yes',
    'ordering duplicate answer': (j) =>
        objectsAt(j, 'questions')[3]['correctOrderItemIds'] = [
          'a',
          'a',
          'c',
          'd',
        ],
    'ordering unknown answer': (j) =>
        objectsAt(j, 'questions')[3]['correctOrderItemIds'] = [
          'a',
          'b',
          'c',
          'z',
        ],
    'ordering short answer': (j) =>
        objectsAt(j, 'questions')[3]['correctOrderItemIds'] = ['a', 'b', 'c'],
    'ordering conflicting choice': (j) =>
        objectsAt(j, 'questions')[3]['correctOptionId'] = 'a',
    'ordering three items': (j) {
      final q = objectsAt(j, 'questions')[3];
      q['items'] = objectsAt(q, 'items').take(3).toList();
    },
  };
  for (final entry in envelopeMutations.entries) {
    test('rejects ${entry.key}', () {
      final json = quickJson();
      entry.value(json);
      expect(() => QuickPlayResponse.fromJson(json).toDomain(), invalid);
    });
  }
  for (final key in [
    'url',
    'altText',
    'source',
    'sourceUrl',
    'attribution',
    'license',
    'licenseUrl',
  ]) {
    test('image requires $key', () {
      final json = quickJson();
      objectAt(objectsAt(json, 'questions')[2], 'image').remove(key);
      expect(() => QuickPlayResponse.fromJson(json).toDomain(), invalid);
    });
  }
  final dailyMutations = <String, void Function(Map<String, Object?>)>{
    'missing assignment': (j) => j.remove('assignmentQuestionCount'),
    'incomplete assignment': (j) => j['assignmentQuestionCount'] = 10,
    'invalid calendar date': (j) =>
        objectAt(j, 'date')['isoDate'] = '2026-02-30',
    'missing display date': (j) => objectAt(j, 'date').remove('displayDate'),
    'blank challenge': (j) => j['challengeId'] = '',
    'zero duration': (j) => objectAt(j, 'timer')['durationSeconds'] = 0,
    'wrong Daily mode': (j) => j['mode'] = 'quick_play',
    'wrong Daily timer': (j) => objectAt(j, 'timer')['mode'] = 'per_question',
    'Daily per-question limit': (j) =>
        objectsAt(j, 'questions').first['timeLimitSeconds'] = 20,
    'Daily optional timer': (j) =>
        objectAt(j, 'timer')['enabledByDefault'] = false,
  };
  for (final entry in dailyMutations.entries) {
    test('rejects ${entry.key}', () {
      final json = dailyJson();
      entry.value(json);
      expect(() => DailyQuizResponse.fromJson(json).toDomain(), invalid);
    });
  }
  test('catalog maps every group and positive defaults', () {
    final json = catalogJson();
    objectAt(json, 'quickPlayTimerDefaultsSeconds')['multipleChoice'] = 11;
    final c = QuizCatalogResponse.fromJson(json).toDomain();
    expect(c.collections.map((v) => v.group), QuizCollectionGroup.values);
    expect(
      c.quickPlayTimerDefaults[QuizQuestionType.multipleChoice]!.inSeconds,
      11,
    );
  });
  final catalogMutations = <String, void Function(Map<String, Object?>)>{
    'missing question counts': (j) => j.remove('questionCounts'),
    'unsupported count': (j) => j['questionCounts'] = [5, 10, 30],
    'duplicate count': (j) => j['questionCounts'] = [5, 5, 20],
    'negative count': (j) =>
        objectAt(j, 'mixed')['publishedQuestionCount'] = -1,
    'missing default': (j) =>
        objectAt(j, 'quickPlayTimerDefaultsSeconds').remove('trueFalse'),
    'zero default': (j) =>
        objectAt(j, 'quickPlayTimerDefaultsSeconds')['trueFalse'] = 0,
    'unknown group': (j) =>
        objectsAt(j, 'collections').first['group'] = 'other',
    'duplicate collection': (j) =>
        objectsAt(j, 'collections')[1]['id'] = 'topic',
    'inconsistent availability': (j) =>
        objectsAt(j, 'collections').first['supportedQuestionCounts'] = [
          5,
          10,
          20,
        ],
  };
  for (final entry in catalogMutations.entries) {
    test('rejects catalog ${entry.key}', () {
      final json = catalogJson();
      entry.value(json);
      expect(() => QuizCatalogResponse.fromJson(json).toDomain(), invalid);
    });
  }
  test('typed parsing includes field path without dumping content', () {
    final json = quickJson();
    objectsAt(json, 'questions')[2]['prompt'] = 123;
    expect(
      () => QuickPlayResponse.fromJson(json),
      throwsA(
        isA<FormatException>().having(
          (e) => e.message,
          'path',
          contains(r'$.questions[2].prompt'),
        ),
      ),
    );
  });
}
