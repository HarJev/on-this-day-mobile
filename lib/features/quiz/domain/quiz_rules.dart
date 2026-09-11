enum QuizQuestionType {
  multipleChoice,
  trueFalse,
  imageIdentification,
  chronologicalOrdering,
}

enum QuizDifficulty { easy, medium, hard }

enum QuizCollectionGroup {
  topic,
  historicalPeriod,
  civilization,
  conflictOrMovement,
}

abstract final class QuizRules {
  static const questionCounts = [5, 10, 20];
  // Defaults describe today's contract, not constructor restrictions.
  static const quickPlayDefaults = {
    QuizQuestionType.multipleChoice: Duration(seconds: 20),
    QuizQuestionType.trueFalse: Duration(seconds: 20),
    QuizQuestionType.imageIdentification: Duration(seconds: 30),
    QuizQuestionType.chronologicalOrdering: Duration(seconds: 45),
  };
  static const dailyDefaults = {
    5: Duration(minutes: 2),
    10: Duration(minutes: 4),
    20: Duration(minutes: 8),
  };
}
