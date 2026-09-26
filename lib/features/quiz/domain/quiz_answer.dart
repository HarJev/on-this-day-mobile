import 'quiz_validation.dart';

sealed class QuizAnswer {
  const QuizAnswer();
}

final class OptionAnswer extends QuizAnswer {
  OptionAnswer(this.optionId) {
    requireId(optionId);
  }
  final String optionId;
}

final class OrderingAnswer extends QuizAnswer {
  OrderingAnswer(List<String> orderedItemIds)
    : orderedItemIds = List.unmodifiable(orderedItemIds) {
    requireQuiz(
      this.orderedItemIds.length == 4 &&
          this.orderedItemIds.toSet().length == 4,
      'Expected four unique answer IDs',
    );
    this.orderedItemIds.forEach(requireId);
  }
  final List<String> orderedItemIds;
}
