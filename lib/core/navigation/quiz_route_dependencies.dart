import '../../features/quiz/application/quiz_completion_coordinator.dart';
import '../../features/quiz/application/quiz_completion_id_generator.dart';
import '../../features/quiz/application/quiz_root_status.dart';
import '../../features/quiz/domain/quiz_repository.dart';
import '../../features/quiz/domain/quiz_result_store.dart';
import '../../features/quiz/presentation/images/quiz_image_preparer.dart';
import '../config/timezone_provider.dart';
import 'source_launcher.dart';

/// App-owned collaborators shared by all Quiz routes. Constructing this bundle
/// does not open SQLite, request catalog data, or prepare images.
final class QuizRouteDependencies {
  const QuizRouteDependencies({
    required this.repository,
    required this.resultStore,
    required this.completionCoordinator,
    required this.imagePreparer,
    required this.timezoneProvider,
    required this.completionIdGenerator,
    required this.sourceLauncher,
    required this.rootStatus,
  });

  final QuizRepository repository;
  final QuizResultStore resultStore;
  final QuizCompletionCoordinator completionCoordinator;
  final QuizImagePreparer imagePreparer;
  final TimezoneProvider timezoneProvider;
  final QuizCompletionIdGenerator completionIdGenerator;
  final SourceLauncher sourceLauncher;
  final QuizRootStatus rootStatus;
}
