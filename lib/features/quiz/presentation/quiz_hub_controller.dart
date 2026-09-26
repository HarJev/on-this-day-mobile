import 'package:flutter/foundation.dart';

import '../application/daily_challenge_status.dart';
import '../domain/quiz_catalog.dart';
import '../domain/quiz_exceptions.dart';
import '../domain/quiz_repository.dart';

sealed class QuizHubState {
  const QuizHubState();
}

final class QuizHubLoading extends QuizHubState {
  const QuizHubLoading();
}

final class QuizHubEmpty extends QuizHubState {
  const QuizHubEmpty({this.dailyStatus});
  final DailyChallengeStatus? dailyStatus;
}

final class QuizHubLoaded extends QuizHubState {
  const QuizHubLoaded({required this.catalog, this.dailyStatus});
  final QuizCatalog catalog;
  final DailyChallengeStatus? dailyStatus;

  QuizHubLoaded copyWith({DailyChallengeStatus? dailyStatus}) =>
      QuizHubLoaded(catalog: catalog, dailyStatus: dailyStatus);
}

final class QuizHubFailure extends QuizHubState {
  const QuizHubFailure({required this.message, required this.kind});
  final String message;
  final QuizFailureKind kind;
}

/// Loads only catalog data. A Daily date is supplied by Daily Setup after a
/// backend response confirms it, so Hub never guesses a restart-time date.
final class QuizHubController extends ChangeNotifier {
  QuizHubController(this._repository);

  final QuizRepository _repository;
  QuizHubState _state = const QuizHubLoading();
  QuizHubState get state => _state;
  DailyChallengeStatus? _dailyStatus;
  int _generation = 0;
  bool _disposed = false;

  Future<void> load() async {
    final generation = ++_generation;
    _setState(const QuizHubLoading());
    try {
      final catalog = await _repository.getCatalog();
      if (!_isCurrent(generation)) return;
      if (catalog.mixed.publishedQuestionCount == 0 &&
          catalog.collections.isEmpty) {
        _setState(QuizHubEmpty(dailyStatus: _dailyStatus));
        return;
      }
      _setState(QuizHubLoaded(catalog: catalog, dailyStatus: _dailyStatus));
    } catch (error) {
      if (!_isCurrent(generation)) return;
      final failure = _failure(error);
      _setState(QuizHubFailure(message: failure.message, kind: failure.kind));
    }
  }

  void updateDailyStatus(DailyChallengeStatus status) {
    _dailyStatus = status;
    switch (_state) {
      case QuizHubLoaded(:final catalog):
        _setState(QuizHubLoaded(catalog: catalog, dailyStatus: status));
      case QuizHubEmpty():
        _setState(QuizHubEmpty(dailyStatus: status));
      case _:
        break;
    }
  }

  _HubFailure _failure(Object error) => switch (error) {
    QuizException(:final kind, :final message) => _HubFailure(kind, message),
    _ => const _HubFailure(
      QuizFailureKind.request,
      'Could not load Quiz. Please try again.',
    ),
  };

  bool _isCurrent(int generation) => !_disposed && generation == _generation;

  void _setState(QuizHubState state) {
    if (_disposed) return;
    _state = state;
    notifyListeners();
  }

  @override
  void dispose() {
    _disposed = true;
    super.dispose();
  }
}

final class _HubFailure {
  const _HubFailure(this.kind, this.message);
  final QuizFailureKind kind;
  final String message;
}
