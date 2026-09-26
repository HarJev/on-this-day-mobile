import 'quiz_definition.dart';
import 'quiz_result.dart';

abstract interface class QuizResultStore {
  /// Missing and unreadable storage are distinct: storage failures must throw.
  Future<StoredQuizResult?> getOfficialDaily(QuizDate date);

  /// Atomically saves the frozen snapshot and comparable best result.
  /// An occupied official date converts a new claim to practice, never replaces
  /// the official result. Explicit practice never claims an empty date.
  /// Identical completion-ID retries return their original classification;
  /// reuse with different snapshot/intent fails. Compare snapshot values, not
  /// object identity. Higher correct count wins bests; ties retain earlier saves.
  /// Return only after commit; failures throw with their diagnostic cause.
  /// Pending date reservations belong to the later app-scoped coordinator.
  Future<StoredQuizResult> saveCompletion(QuizCompletion completion);

  Future<StoredQuizResult?> getBestResult(QuizBestResultKey key);
  Future<bool> getQuickPlayTimingEnabled();
  Future<void> setQuickPlayTimingEnabled(bool enabled);
}
