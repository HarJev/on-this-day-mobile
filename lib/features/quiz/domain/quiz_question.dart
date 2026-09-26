import 'quiz_image.dart';
import 'quiz_rules.dart';
import 'quiz_source.dart';
import 'quiz_validation.dart';

final class QuizOption {
  QuizOption(this.id, this.text) {
    requireId(id);
    requireText(text);
  }
  final String id, text;
}

final class QuizOrderingItem {
  QuizOrderingItem(this.id, this.text) {
    requireId(id);
    requireText(text);
  }
  final String id, text;
}

sealed class QuizQuestion {
  QuizQuestion({
    required this.id,
    required this.difficulty,
    required this.prompt,
    required this.explanation,
    required List<QuizSource> sources,
  }) : sources = List.unmodifiable(sources) {
    requireId(id);
    requireText(prompt);
    requireText(explanation);
    requireQuiz(
      this.sources.isNotEmpty &&
          this.sources.map((s) => s.url).toSet().length == this.sources.length,
      'Sources must be nonempty and unique',
    );
  }
  final String id, prompt, explanation;
  final QuizDifficulty difficulty;
  final List<QuizSource> sources;
  QuizQuestionType get type;
}

sealed class ChoiceQuestion extends QuizQuestion {
  ChoiceQuestion({
    required super.id,
    required super.difficulty,
    required super.prompt,
    required super.explanation,
    required super.sources,
    required List<QuizOption> options,
    required this.correctOptionId,
    required int optionCount,
  }) : options = List.unmodifiable(options) {
    requireQuiz(
      this.options.length == optionCount &&
          this.options.map((o) => o.id).toSet().length == optionCount,
      'Invalid option cardinality',
    );
    requireQuiz(
      this.options.any((o) => o.id == correctOptionId),
      'Unknown correct option',
    );
  }
  final List<QuizOption> options;
  final String correctOptionId;
}

final class MultipleChoiceQuestion extends ChoiceQuestion {
  MultipleChoiceQuestion({
    required super.id,
    required super.difficulty,
    required super.prompt,
    required super.explanation,
    required super.sources,
    required super.options,
    required super.correctOptionId,
  }) : super(optionCount: 4);
  @override
  QuizQuestionType get type => QuizQuestionType.multipleChoice;
}

final class TrueFalseQuestion extends ChoiceQuestion {
  TrueFalseQuestion({
    required super.id,
    required super.difficulty,
    required super.prompt,
    required super.explanation,
    required super.sources,
    required super.options,
    required super.correctOptionId,
  }) : super(optionCount: 2) {
    requireQuiz(
      options[0].id == 'true' &&
          options[0].text == 'True' &&
          options[1].id == 'false' &&
          options[1].text == 'False',
      'Expected canonical True/False options',
    );
  }
  @override
  QuizQuestionType get type => QuizQuestionType.trueFalse;
}

final class ImageIdentificationQuestion extends ChoiceQuestion {
  ImageIdentificationQuestion({
    required super.id,
    required super.difficulty,
    required super.prompt,
    required super.explanation,
    required super.sources,
    required super.options,
    required super.correctOptionId,
    required this.image,
  }) : super(optionCount: 4);
  final QuizImage image;
  @override
  QuizQuestionType get type => QuizQuestionType.imageIdentification;
}

final class ChronologicalOrderingQuestion extends QuizQuestion {
  ChronologicalOrderingQuestion({
    required super.id,
    required super.difficulty,
    required super.prompt,
    required super.explanation,
    required super.sources,
    required List<QuizOrderingItem> items,
    required List<String> correctOrderItemIds,
  }) : items = List.unmodifiable(items),
       correctOrderItemIds = List.unmodifiable(correctOrderItemIds) {
    requireQuiz(
      this.items.length == 4 && this.items.map((i) => i.id).toSet().length == 4,
      'Expected four distinct items',
    );
    requirePermutation(this.correctOrderItemIds, this.items.map((i) => i.id));
  }
  final List<QuizOrderingItem> items;
  final List<String> correctOrderItemIds;
  @override
  QuizQuestionType get type => QuizQuestionType.chronologicalOrdering;
}
