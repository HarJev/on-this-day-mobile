import 'dart:async';

import 'package:flutter/foundation.dart';

import '../domain/quiz_definition.dart';
import '../domain/quiz_result.dart';
import '../domain/quiz_result_store.dart';

enum QuizCompletionSaveStatus { pending, saved, failed }

final class QuizCompletionSaveState {
  const QuizCompletionSaveState({
    required this.completion,
    required this.requestedIntent,
    required this.effectiveIntent,
    required this.status,
    this.storedResult,
    this.error,
  });
  final QuizCompletion completion;
  final QuizSaveIntent requestedIntent;
  final QuizSaveIntent effectiveIntent;
  final QuizCompletionSaveStatus status;
  final StoredQuizResult? storedResult;
  final Object? error;
}

/// Coordinates app-lifetime Daily claims above the persistence boundary.
/// It deliberately depends only on the domain store contract, never SQLite.
final class QuizCompletionCoordinator extends ChangeNotifier {
  QuizCompletionCoordinator(this._store);
  final QuizResultStore _store;
  final Map<String, _Entry> _entries = {};
  final Map<QuizDate, _DailyReservation> _dailyReservations = {};
  bool _disposed = false;

  QuizCompletionSaveState? stateFor(String completionId) =>
      _entries[completionId]?.state;

  Future<void> Function(QuizResult) sinkFor(QuizSaveIntent intent) =>
      (result) => complete(QuizCompletion(result, intent)).then<void>((_) {});

  Future<StoredQuizResult> complete(QuizCompletion completion) {
    final existing = _entries[completion.result.completionId];
    if (existing != null) return existing.operation;
    final effectiveIntent = _effectiveIntent(completion);
    final effective = QuizCompletion(completion.result, effectiveIntent);
    final entry = _Entry(
      QuizCompletionSaveState(
        completion: effective,
        requestedIntent: completion.intent,
        effectiveIntent: effectiveIntent,
        status: QuizCompletionSaveStatus.pending,
      ),
    );
    _entries[completion.result.completionId] = entry;
    _reserveDaily(effective);
    _notify();
    _startSave(entry);
    return entry.operation;
  }

  Future<StoredQuizResult> retry(String completionId) {
    final entry = _entries[completionId];
    if (entry == null) throw StateError('Unknown completion ID');
    if (entry.state.status == QuizCompletionSaveStatus.pending) {
      return entry.operation;
    }
    if (entry.state.status == QuizCompletionSaveStatus.saved) {
      return entry.operation;
    }
    entry.state = QuizCompletionSaveState(
      completion: entry.state.completion,
      requestedIntent: entry.state.requestedIntent,
      effectiveIntent: entry.state.effectiveIntent,
      status: QuizCompletionSaveStatus.pending,
    );
    entry.restart();
    _notify();
    _startSave(entry);
    return entry.operation;
  }

  QuizSaveIntent _effectiveIntent(QuizCompletion completion) {
    if (completion.intent != QuizSaveIntent.claimDailyIfAbsent) {
      return completion.intent;
    }
    final daily = completion.result.definition as DailyQuizDefinition;
    final reservation = _dailyReservations[daily.date];
    return reservation == null
        ? QuizSaveIntent.claimDailyIfAbsent
        : QuizSaveIntent.practice;
  }

  void _reserveDaily(QuizCompletion completion) {
    if (completion.intent != QuizSaveIntent.claimDailyIfAbsent) return;
    final daily = completion.result.definition as DailyQuizDefinition;
    _dailyReservations[daily.date] = _DailyReservation.pending(
      completion.result.completionId,
    );
  }

  Future<StoredQuizResult> _save(_Entry entry) async {
    try {
      final saved = await _store.saveCompletion(entry.state.completion);
      entry.state = QuizCompletionSaveState(
        completion: entry.state.completion,
        requestedIntent: entry.state.requestedIntent,
        effectiveIntent: entry.state.effectiveIntent,
        status: QuizCompletionSaveStatus.saved,
        storedResult: saved,
      );
      final definition = entry.state.completion.result.definition;
      if (definition is DailyQuizDefinition &&
          entry.state.requestedIntent == QuizSaveIntent.claimDailyIfAbsent) {
        _dailyReservations[definition.date] = _DailyReservation.occupied();
      }
      _notify();
      return saved;
    } catch (error) {
      entry.state = QuizCompletionSaveState(
        completion: entry.state.completion,
        requestedIntent: entry.state.requestedIntent,
        effectiveIntent: entry.state.effectiveIntent,
        status: QuizCompletionSaveStatus.failed,
        error: error,
      );
      _notify();
      rethrow;
    }
  }

  void _startSave(_Entry entry) {
    () async {
      try {
        entry.succeed(await _save(entry));
      } catch (error, stackTrace) {
        entry.fail(error, stackTrace);
      }
    }();
  }

  void _notify() {
    if (!_disposed) notifyListeners();
  }

  @override
  void dispose() {
    _disposed = true;
    super.dispose();
  }
}

final class _Entry {
  _Entry(this.state);
  QuizCompletionSaveState state;
  Completer<StoredQuizResult> _completion = Completer<StoredQuizResult>();

  Future<StoredQuizResult> get operation => _completion.future;

  void restart() => _completion = Completer<StoredQuizResult>();

  void succeed(StoredQuizResult result) => _completion.complete(result);

  void fail(Object error, StackTrace stackTrace) =>
      _completion.completeError(error, stackTrace);
}

final class _DailyReservation {
  const _DailyReservation.pending(this.completionId) : occupied = false;
  const _DailyReservation.occupied() : completionId = null, occupied = true;
  final String? completionId;
  final bool occupied;
}
