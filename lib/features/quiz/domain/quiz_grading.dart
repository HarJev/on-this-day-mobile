import 'quiz_answer.dart';
import 'quiz_question.dart';
import 'quiz_validation.dart';

bool gradeQuizAnswer(QuizQuestion question, QuizAnswer answer) {
  switch (question) {
    case ChoiceQuestion():
      requireQuiz(answer is OptionAnswer, 'Choice requires an option answer');
      final id = (answer as OptionAnswer).optionId;
      requireQuiz(
        question.options.any((o) => o.id == id),
        'Unknown answer option',
      );
      return id == question.correctOptionId;
    case ChronologicalOrderingQuestion():
      requireQuiz(
        answer is OrderingAnswer,
        'Ordering requires an ordered answer',
      );
      final ids = (answer as OrderingAnswer).orderedItemIds;
      requirePermutation(ids, question.items.map((i) => i.id));
      return List.generate(
        ids.length,
        (i) => ids[i] == question.correctOrderItemIds[i],
      ).every((v) => v);
  }
}
