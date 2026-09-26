import '../../domain/quiz_question.dart';
import '../../domain/quiz_rules.dart';
import 'quiz_image_response.dart';
import 'quiz_json.dart';
import 'quiz_source_response.dart';

final class QuizQuestionResponse {
  QuizQuestionResponse.fromJson(QuizJson json, {required bool quickPlay})
    : id = json.string('id'),
      prompt = json.string('prompt'),
      explanation = json.string('explanation'),
      type = json.enumValue('type', const {
        'multiple_choice': QuizQuestionType.multipleChoice,
        'true_false': QuizQuestionType.trueFalse,
        'image_identification': QuizQuestionType.imageIdentification,
        'chronological_ordering': QuizQuestionType.chronologicalOrdering,
      }),
      difficulty = json.enumValue('difficulty', const {
        'easy': QuizDifficulty.easy,
        'medium': QuizDifficulty.medium,
        'hard': QuizDifficulty.hard,
      }),
      sources = List.unmodifiable(
        json.objects('sources').map(QuizSourceResponse.fromJson),
      ),
      timeLimit = quickPlay ? json.duration('timeLimitSeconds') : null {
    if (!quickPlay) json.prohibit('timeLimitSeconds');
    if (type == QuizQuestionType.chronologicalOrdering) {
      json.prohibit('options');
      json.prohibit('correctOptionId');
      items = List.unmodifiable(
        json
            .objects('items')
            .map((v) => QuizOrderingItem(v.string('id'), v.string('text'))),
      );
      correctOrderItemIds = List.unmodifiable(
        json.strings('correctOrderItemIds'),
      );
      options = null;
      correctOptionId = null;
    } else {
      json.prohibit('items');
      json.prohibit('correctOrderItemIds');
      options = List.unmodifiable(
        json
            .objects('options')
            .map((v) => QuizOption(v.string('id'), v.string('text'))),
      );
      correctOptionId = json.string('correctOptionId');
      items = null;
      correctOrderItemIds = null;
    }
    if (type == QuizQuestionType.imageIdentification) {
      image = QuizImageResponse.fromJson(json.object('image'));
    } else {
      json.prohibit('image');
      image = null;
    }
  }

  final String id, prompt, explanation;
  final QuizQuestionType type;
  final QuizDifficulty difficulty;
  final List<QuizSourceResponse> sources;
  final Duration? timeLimit;
  late final List<QuizOption>? options;
  late final String? correctOptionId;
  late final List<QuizOrderingItem>? items;
  late final List<String>? correctOrderItemIds;
  late final QuizImageResponse? image;

  QuizQuestion toDomain() {
    final domainSources = sources.map((s) => s.toDomain()).toList();
    return switch (type) {
      QuizQuestionType.multipleChoice => MultipleChoiceQuestion(
        id: id,
        difficulty: difficulty,
        prompt: prompt,
        explanation: explanation,
        sources: domainSources,
        options: options!,
        correctOptionId: correctOptionId!,
      ),
      QuizQuestionType.trueFalse => TrueFalseQuestion(
        id: id,
        difficulty: difficulty,
        prompt: prompt,
        explanation: explanation,
        sources: domainSources,
        options: options!,
        correctOptionId: correctOptionId!,
      ),
      QuizQuestionType.imageIdentification => ImageIdentificationQuestion(
        id: id,
        difficulty: difficulty,
        prompt: prompt,
        explanation: explanation,
        sources: domainSources,
        options: options!,
        correctOptionId: correctOptionId!,
        image: image!.toDomain(),
      ),
      QuizQuestionType.chronologicalOrdering => ChronologicalOrderingQuestion(
        id: id,
        difficulty: difficulty,
        prompt: prompt,
        explanation: explanation,
        sources: domainSources,
        items: items!,
        correctOrderItemIds: correctOrderItemIds!,
      ),
    };
  }
}
