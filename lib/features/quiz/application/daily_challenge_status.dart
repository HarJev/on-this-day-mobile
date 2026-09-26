import '../domain/quiz_definition.dart';
import '../domain/quiz_result.dart';
import 'quiz_completion_coordinator.dart';

/// A date is safe to present only after a Daily API response supplied it.
final class DailyChallengeStatus {
  const DailyChallengeStatus({
    required this.date,
    required this.displayDate,
    this.confirmedOfficialResult,
    this.reservation,
  });

  final QuizDate date;
  final String displayDate;
  final StoredQuizResult? confirmedOfficialResult;
  final DailyReservationSnapshot? reservation;

  bool get hasConfirmedOfficial => confirmedOfficialResult != null;
  bool get blocksOfficialClaim =>
      confirmedOfficialResult != null || reservation != null;
}
