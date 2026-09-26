import 'package:flutter/foundation.dart';

import 'daily_challenge_status.dart';

/// Presentation-only state for the retained Quiz Hub. Durable results remain
/// owned by [QuizResultStore] and app-lifetime pending claims by its coordinator.
final class QuizRootStatus extends ValueNotifier<DailyChallengeStatus?> {
  QuizRootStatus() : super(null);

  void update(DailyChallengeStatus status) => value = status;
}
