import 'dart:convert';

import 'package:crypto/crypto.dart';

import '../../domain/question_outcome.dart';
import '../../domain/quiz_answer.dart';
import '../../domain/quiz_definition.dart';
import '../../domain/quiz_exceptions.dart';
import '../../domain/quiz_image.dart';
import '../../domain/quiz_question.dart';
import '../../domain/quiz_result.dart';
import '../../domain/quiz_rules.dart';
import '../../domain/quiz_source.dart';

/// Versioned, canonical local representation of a frozen result. SHA-256 is
/// used for deterministic idempotency, never as a security boundary.
final class QuizResultSnapshotCodec {
  static const version = 1;

  const QuizResultSnapshotCodec();

  String encode(QuizResult result) =>
      jsonEncode(_canonical(_resultMap(result)));

  String fingerprint(QuizResult result) => _fingerprintMap(_resultMap(result));

  QuizResult decode(String encoded) {
    try {
      final decoded = jsonDecode(encoded);
      if (decoded is! Map) throw const FormatException('Expected object');
      return _resultFromMap(Map<String, Object?>.from(decoded));
    } on QuizStorageException {
      rethrow;
    } catch (error) {
      throw QuizStorageCorruptionException(
        'Stored quiz result has an invalid snapshot.',
        cause: error,
      );
    }
  }

  String fingerprintEncoded(String encoded) => fingerprint(decode(encoded));

  String _fingerprintMap(Map<String, Object?> value) =>
      sha256.convert(utf8.encode(jsonEncode(_canonical(value)))).toString();

  Object? _canonical(Object? value) {
    if (value is Map) {
      final entries =
          value.entries
              .map(
                (entry) =>
                    MapEntry(entry.key.toString(), _canonical(entry.value)),
              )
              .toList()
            ..sort((left, right) => left.key.compareTo(right.key));
      return {for (final entry in entries) entry.key: entry.value};
    }
    if (value is List) return value.map(_canonical).toList(growable: false);
    return value;
  }

  Map<String, Object?> _resultMap(QuizResult result) => {
    'snapshotVersion': version,
    'completionId': result.completionId,
    'definition': _definitionMap(result.definition),
    'timingEnabled': result.timingEnabled,
    'completedAt': result.completedAt.toUtc().toIso8601String(),
    'reason': result.reason.name,
    'outcomes': result.outcomes.map(_outcomeMap).toList(growable: false),
  };

  Map<String, Object?> _definitionMap(QuizDefinition definition) => {
    'mode': definition is DailyQuizDefinition ? 'daily' : 'quickPlay',
    'questionCount': definition.questionCount,
    'questions': definition.questions.map(_questionMap).toList(growable: false),
    if (definition case DailyQuizDefinition()) ...{
      'challengeId': definition.challengeId,
      'date': definition.date.isoDate,
      'displayDate': definition.displayDate,
      'durationMs': definition.duration.inMilliseconds,
      'assignmentQuestionCount': definition.assignmentQuestionCount,
    } else if (definition case QuickPlayQuizDefinition()) ...{
      'selection': {
        'collectionId': definition.selection.collectionId,
        'displayName': definition.selection.displayName,
      },
      'timingEnabledByDefault': definition.timingEnabledByDefault,
      'questionTimeLimitsMs': {
        for (final entry in definition.questionTimeLimits.entries)
          entry.key: entry.value.inMilliseconds,
      },
    },
  };

  Map<String, Object?> _questionMap(QuizQuestion question) => {
    'id': question.id,
    'type': question.type.name,
    'difficulty': question.difficulty.name,
    'prompt': question.prompt,
    'explanation': question.explanation,
    'sources': question.sources
        .map(
          (source) => {
            'displayName': source.displayName,
            'url': source.url.toString(),
          },
        )
        .toList(growable: false),
    if (question case ChoiceQuestion()) ...{
      'options': question.options
          .map((option) => {'id': option.id, 'text': option.text})
          .toList(growable: false),
      'correctOptionId': question.correctOptionId,
    } else if (question case ChronologicalOrderingQuestion()) ...{
      'items': question.items
          .map((item) => {'id': item.id, 'text': item.text})
          .toList(growable: false),
      'correctOrderItemIds': question.correctOrderItemIds,
    },
    if (question case ImageIdentificationQuestion())
      'image': {
        'url': question.image.url.toString(),
        'altText': question.image.altText,
        'source': question.image.source,
        'sourceUrl': question.image.sourceUrl.toString(),
        'attribution': question.image.attribution,
        'creator': question.image.creator,
        'license': question.image.license,
        'licenseUrl': question.image.licenseUrl.toString(),
      },
  };

  Map<String, Object?> _outcomeMap(QuestionOutcome outcome) => {
    'questionId': outcome.question.id,
    'kind': outcome.kind.name,
    'answer': switch (outcome.answer) {
      OptionAnswer(:final optionId) => {'kind': 'option', 'optionId': optionId},
      OrderingAnswer(:final orderedItemIds) => {
        'kind': 'ordering',
        'orderedItemIds': orderedItemIds,
      },
      null => null,
    },
    'unansweredReason': outcome.unansweredReason?.name,
  };

  QuizResult _resultFromMap(Map<String, Object?> map) {
    if (_int(map, 'snapshotVersion') != version) {
      throw const FormatException('Unsupported snapshot version');
    }
    final definition = _definitionFromMap(_object(map, 'definition'));
    final questions = {
      for (final question in definition.questions) question.id: question,
    };
    final outcomes = _list(map, 'outcomes')
        .map((value) {
          final outcome = _objectValue(value);
          final question = questions[_string(outcome, 'questionId')];
          if (question == null) {
            throw const FormatException('Unknown outcome question');
          }
          final kind = _enumByName(
            QuestionOutcomeKind.values,
            _string(outcome, 'kind'),
          );
          final answer = _answerFromMap(outcome['answer']);
          final unanswered = outcome['unansweredReason'] == null
              ? null
              : _enumByName(
                  UnansweredReason.values,
                  outcome['unansweredReason'] as String,
                );
          return switch (kind) {
            QuestionOutcomeKind.correct || QuestionOutcomeKind.incorrect =>
              _validatedAnswered(question, answer, kind),
            QuestionOutcomeKind.timedOut => _validatedTimedOut(
              question,
              answer,
              unanswered,
            ),
            QuestionOutcomeKind.unanswered => _validatedUnanswered(
              question,
              answer,
              unanswered,
            ),
          };
        })
        .toList(growable: false);
    return QuizResult(
      completionId: _string(map, 'completionId'),
      definition: definition,
      timingEnabled: _bool(map, 'timingEnabled'),
      completedAt: DateTime.parse(_string(map, 'completedAt')).toUtc(),
      reason: _enumByName(QuizCompletionReason.values, _string(map, 'reason')),
      outcomes: outcomes,
    );
  }

  QuestionOutcome _validatedAnswered(
    QuizQuestion question,
    QuizAnswer? answer,
    QuestionOutcomeKind expected,
  ) {
    if (answer == null) {
      throw const FormatException('Answered outcome lacks answer');
    }
    final outcome = QuestionOutcome.answered(question, answer);
    if (outcome.kind != expected) {
      throw const FormatException('Stored outcome does not match answer');
    }
    return outcome;
  }

  QuestionOutcome _validatedTimedOut(
    QuizQuestion question,
    QuizAnswer? answer,
    UnansweredReason? reason,
  ) {
    if (answer != null || reason != null) {
      throw const FormatException('Invalid timeout outcome');
    }
    return QuestionOutcome.timedOut(question);
  }

  QuestionOutcome _validatedUnanswered(
    QuizQuestion question,
    QuizAnswer? answer,
    UnansweredReason? reason,
  ) {
    if (answer != null || reason == null) {
      throw const FormatException('Invalid unanswered outcome');
    }
    return QuestionOutcome.unanswered(question, reason);
  }

  QuizDefinition _definitionFromMap(Map<String, Object?> map) {
    final questions = _list(map, 'questions')
        .map((value) => _questionFromMap(_objectValue(value)))
        .toList(growable: false);
    final count = _int(map, 'questionCount');
    switch (_string(map, 'mode')) {
      case 'daily':
        return DailyQuizDefinition(
          questionCount: count,
          questions: questions,
          challengeId: _string(map, 'challengeId'),
          date: QuizDate(_string(map, 'date')),
          displayDate: _string(map, 'displayDate'),
          duration: Duration(milliseconds: _int(map, 'durationMs')),
          assignmentQuestionCount: _int(map, 'assignmentQuestionCount'),
        );
      case 'quickPlay':
        final selection = _object(map, 'selection');
        final limits = _object(map, 'questionTimeLimitsMs');
        return QuickPlayQuizDefinition(
          questionCount: count,
          questions: questions,
          selection: QuizSelection(
            collectionId: selection['collectionId'] as String?,
            displayName: _string(selection, 'displayName'),
          ),
          timingEnabledByDefault: _bool(map, 'timingEnabledByDefault'),
          questionTimeLimits: {
            for (final entry in limits.entries)
              entry.key: Duration(milliseconds: _intValue(entry.value)),
          },
        );
      default:
        throw const FormatException('Unknown quiz mode');
    }
  }

  QuizQuestion _questionFromMap(Map<String, Object?> map) {
    final type = _enumByName(QuizQuestionType.values, _string(map, 'type'));
    final common = (
      id: _string(map, 'id'),
      difficulty: _enumByName(
        QuizDifficulty.values,
        _string(map, 'difficulty'),
      ),
      prompt: _string(map, 'prompt'),
      explanation: _string(map, 'explanation'),
      sources: _list(map, 'sources')
          .map((value) {
            final source = _objectValue(value);
            return QuizSource(
              displayName: _string(source, 'displayName'),
              url: Uri.parse(_string(source, 'url')),
            );
          })
          .toList(growable: false),
    );
    if (type == QuizQuestionType.chronologicalOrdering) {
      return ChronologicalOrderingQuestion(
        id: common.id,
        difficulty: common.difficulty,
        prompt: common.prompt,
        explanation: common.explanation,
        sources: common.sources,
        items: _list(map, 'items')
            .map((value) {
              final item = _objectValue(value);
              return QuizOrderingItem(
                _string(item, 'id'),
                _string(item, 'text'),
              );
            })
            .toList(growable: false),
        correctOrderItemIds: _strings(map, 'correctOrderItemIds'),
      );
    }
    final options = _list(map, 'options')
        .map((value) {
          final option = _objectValue(value);
          return QuizOption(_string(option, 'id'), _string(option, 'text'));
        })
        .toList(growable: false);
    final correct = _string(map, 'correctOptionId');
    switch (type) {
      case QuizQuestionType.multipleChoice:
        return MultipleChoiceQuestion(
          id: common.id,
          difficulty: common.difficulty,
          prompt: common.prompt,
          explanation: common.explanation,
          sources: common.sources,
          options: options,
          correctOptionId: correct,
        );
      case QuizQuestionType.trueFalse:
        return TrueFalseQuestion(
          id: common.id,
          difficulty: common.difficulty,
          prompt: common.prompt,
          explanation: common.explanation,
          sources: common.sources,
          options: options,
          correctOptionId: correct,
        );
      case QuizQuestionType.imageIdentification:
        final image = _object(map, 'image');
        return ImageIdentificationQuestion(
          id: common.id,
          difficulty: common.difficulty,
          prompt: common.prompt,
          explanation: common.explanation,
          sources: common.sources,
          options: options,
          correctOptionId: correct,
          image: QuizImage(
            url: Uri.parse(_string(image, 'url')),
            altText: _string(image, 'altText'),
            source: _string(image, 'source'),
            sourceUrl: Uri.parse(_string(image, 'sourceUrl')),
            attribution: _string(image, 'attribution'),
            creator: image['creator'] as String?,
            license: _string(image, 'license'),
            licenseUrl: Uri.parse(_string(image, 'licenseUrl')),
          ),
        );
      case QuizQuestionType.chronologicalOrdering:
        throw StateError('Handled above');
    }
  }

  QuizAnswer? _answerFromMap(Object? value) {
    if (value == null) return null;
    final map = _objectValue(value);
    return switch (_string(map, 'kind')) {
      'option' => OptionAnswer(_string(map, 'optionId')),
      'ordering' => OrderingAnswer(_strings(map, 'orderedItemIds')),
      _ => throw const FormatException('Unknown answer kind'),
    };
  }

  Map<String, Object?> _object(Map<String, Object?> map, String key) =>
      _objectValue(map[key]);
  Map<String, Object?> _objectValue(Object? value) {
    if (value is! Map) throw const FormatException('Expected object');
    return Map<String, Object?>.from(value);
  }

  List<Object?> _list(Map<String, Object?> map, String key) {
    final value = map[key];
    if (value is! List) throw const FormatException('Expected list');
    return List<Object?>.from(value);
  }

  String _string(Map<String, Object?> map, String key) {
    final value = map[key];
    if (value is! String) throw const FormatException('Expected string');
    return value;
  }

  List<String> _strings(Map<String, Object?> map, String key) => _list(map, key)
      .map((value) {
        if (value is! String) {
          throw const FormatException('Expected string list');
        }
        return value;
      })
      .toList(growable: false);
  int _int(Map<String, Object?> map, String key) => _intValue(map[key]);
  int _intValue(Object? value) {
    if (value is! int) throw const FormatException('Expected integer');
    return value;
  }

  bool _bool(Map<String, Object?> map, String key) {
    final value = map[key];
    if (value is! bool) throw const FormatException('Expected boolean');
    return value;
  }

  T _enumByName<T extends Enum>(List<T> values, String name) =>
      values.where((value) => value.name == name).singleOrNull ??
      (throw const FormatException('Unknown enum'));
}
