import 'quiz_catalog.dart';
import 'quiz_definition.dart';

abstract interface class QuizRepository {
  Future<QuizCatalog> getCatalog();
  Future<QuickPlayQuizDefinition> createQuickPlay({
    required int questionCount,
    String? collectionId,
  });
  Future<DailyQuizDefinition> getDaily({
    required String timezone,
    required int questionCount,
  });
}
