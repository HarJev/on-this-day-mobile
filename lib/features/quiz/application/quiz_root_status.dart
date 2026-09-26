import 'package:flutter/foundation.dart';

import 'daily_challenge_status.dart';
import 'quiz_completion_coordinator.dart';

/// Presentation-only state for the retained Quiz Hub. Durable results remain
/// owned by [QuizResultStore] and app-lifetime pending claims by its coordinator.
///
/// Once Daily Setup has supplied a backend date, completion updates for that
/// date refresh the Hub without refetching. A score appears only after the
/// coordinator confirms an official stored result.
final class QuizRootStatus extends ValueNotifier<DailyChallengeStatus?> {
  QuizRootStatus(this._completions) : super(null) {
    _completions.addListener(_reconcile);
  }

  final QuizCompletionCoordinator _completions;

  void update(DailyChallengeStatus status) => value = _withCompletions(status);

  void _reconcile() {
    final current = value;
    if (current == null) return;
    value = _withCompletions(current);
  }

  /// Returns [status] unchanged unless the coordinator knows more about its
  /// date. A confirmed official result is never replaced.
  DailyChallengeStatus _withCompletions(DailyChallengeStatus status) {
    if (status.hasConfirmedOfficial) return status;
    final reservation = _completions.dailyReservationFor(status.date);
    if (reservation == null) return status;
    final official = _completions.confirmedOfficialDailyFor(status.date);
    final previous = status.reservation;
    if (official == null &&
        previous != null &&
        previous.status == reservation.status &&
        previous.classification == reservation.classification) {
      return status;
    }
    return DailyChallengeStatus(
      date: status.date,
      displayDate: status.displayDate,
      confirmedOfficialResult: official,
      reservation: reservation,
    );
  }

  @override
  void dispose() {
    _completions.removeListener(_reconcile);
    super.dispose();
  }
}
