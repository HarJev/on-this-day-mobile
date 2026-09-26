import '../../features/quiz/application/quiz_session_launch_request.dart';
import '../../features/quiz/domain/quiz_catalog.dart';
import '../../features/quiz/domain/quiz_result.dart';

final class DailySetupRouteArguments {
  const DailySetupRouteArguments(this.catalog);
  final QuizCatalog catalog;
}

final class QuickPlaySetupRouteArguments {
  const QuickPlaySetupRouteArguments(this.catalog);
  final QuizCatalog catalog;
}

final class GameplayRouteArguments {
  const GameplayRouteArguments(this.launch);
  final QuizSessionLaunchRequest launch;
}

final class ResultsRouteArguments {
  const ResultsRouteArguments(this.completionId);
  final String completionId;
}

final class ReviewRouteArguments {
  const ReviewRouteArguments(this.result);
  final QuizResult result;
}
