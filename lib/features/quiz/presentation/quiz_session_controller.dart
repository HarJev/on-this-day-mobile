import 'dart:async';

import 'package:flutter/foundation.dart';

import '../domain/question_outcome.dart';
import '../domain/quiz_answer.dart';
import '../domain/quiz_definition.dart';
import '../domain/quiz_question.dart';
import '../domain/quiz_result.dart';
import '../domain/quiz_validation.dart';
import 'quiz_session_clock.dart';
import 'quiz_session_preparation.dart';
import 'quiz_session_scheduler.dart';
import 'quiz_session_state.dart';

final class QuizSessionController extends ChangeNotifier {
  QuizSessionController({
    required this.definition,
    required this.completionId,
    required this.timingEnabled,
    required QuizSessionClock clock,
    required QuizSessionScheduler scheduler,
    required PrepareQuizSession prepareSession,
    required Future<void> Function(QuizResult) completionSink,
  }) : _clock = clock,
       _scheduler = scheduler,
       _prepareSession = prepareSession,
       _completionSink = completionSink {
    requireText(completionId);
    requireQuiz(
      definition is! DailyQuizDefinition || timingEnabled,
      'Daily must be timed',
    );
  }

  final QuizDefinition definition;
  final String completionId;
  final bool timingEnabled;
  final QuizSessionClock _clock;
  final QuizSessionScheduler _scheduler;
  final PrepareQuizSession _prepareSession;
  final Future<void> Function(QuizResult) _completionSink;
  QuizSessionState _state = const QuizPreparing();
  QuizSessionState get state => _state;
  bool _disposed = false, _terminal = false;
  int _notificationDepth = 0;
  bool _appActive = true, _routeVisible = true;
  bool get _visible => _appActive && _routeVisible;
  int _preparationGeneration = 0, _tickerGeneration = 0;
  QuizPreparationAttempt? _attempt;
  QuizPreparedResources? _resources;
  void Function()? _cancelTicker;
  int _index = 0;
  final List<QuestionOutcome> _outcomes = [];
  List<String> _draft = const [];
  Duration? _remaining;
  Duration? _baselineElapsed;
  DateTime? _baselineUtc;

  Future<void> prepare() async {
    if (_disposed ||
        _terminal ||
        (_state is! QuizPreparing && _state is! QuizPreparationFailed)) {
      return;
    }
    final generation = ++_preparationGeneration;
    _cancelPreparation();
    _state = const QuizPreparing();
    _emit();
    if (_disposed || _terminal || generation != _preparationGeneration) return;
    try {
      final attempt = _prepareSession(definition);
      if (_disposed || _terminal || generation != _preparationGeneration) {
        _cleanup(attempt.cancel);
      } else {
        _attempt = attempt;
      }
      final resources = await attempt.result;
      if (_disposed || _terminal || generation != _preparationGeneration) {
        _cleanup(resources.release);
        return;
      }
      _attempt = null;
      _resources = resources;
      _state = const QuizReady();
      _emit();
    } catch (error) {
      if (_disposed || _terminal || generation != _preparationGeneration) {
        return;
      }
      _cancelPreparation();
      _state = QuizPreparationFailed(error);
      _emit();
    }
  }

  void start() {
    if (_disposed || _terminal || !_visible || _state is! QuizReady) return;
    if (definition case DailyQuizDefinition(:final duration)) {
      _remaining = duration;
    }
    _beginQuestion();
    _emit();
  }

  void answerOption(String questionId, String optionId) {
    if (!_canAnswer(questionId)) return;
    if (definition.questions[_index] is! ChoiceQuestion) return;
    _commit(
      QuestionOutcome.answered(
        definition.questions[_index],
        OptionAnswer(optionId),
      ),
    );
  }

  void updateOrderingDraft(String questionId, List<String> ids) {
    if (!_canAnswer(questionId)) return;
    final question = definition.questions[_index];
    if (question is! ChronologicalOrderingQuestion) return;
    requirePermutation(ids, question.items.map((item) => item.id));
    _draft = List.unmodifiable(ids);
    _refreshState();
    _emit();
  }

  void submitOrder(String questionId) {
    if (!_canAnswer(questionId) ||
        definition.questions[_index] is! ChronologicalOrderingQuestion) {
      return;
    }
    _commit(
      QuestionOutcome.answered(
        definition.questions[_index],
        OrderingAnswer(_draft),
      ),
    );
  }

  void skipImage(String questionId) {
    if (!_canAnswer(questionId) ||
        definition.questions[_index] is! ImageIdentificationQuestion) {
      return;
    }
    _commit(
      QuestionOutcome.unanswered(
        definition.questions[_index],
        UnansweredReason.imageSkipped,
      ),
    );
  }

  bool _canAnswer(String questionId) {
    if (_disposed || _terminal) return false;
    _reconcile();
    return !_terminal &&
        _visible &&
        _state is QuizAnswering &&
        definition.questions[_index].id == questionId;
  }

  void continueQuiz(String questionId) {
    if (_disposed || _terminal) return;
    _reconcile();
    if (_terminal ||
        !_visible ||
        _state is! QuizFeedback ||
        definition.questions[_index].id != questionId) {
      return;
    }
    _index++;
    _beginQuestion();
    _emit();
  }

  void _beginQuestion() {
    final question = definition.questions[_index];
    _draft = question is ChronologicalOrderingQuestion
        ? List.unmodifiable(question.items.map((i) => i.id))
        : const [];
    if (definition case QuickPlayQuizDefinition(:final questionTimeLimits)) {
      _remaining = timingEnabled ? questionTimeLimits[question.id] : null;
    }
    _resetBaseline();
    _state = QuizAnswering(
      index: _index,
      question: question,
      remaining: _remaining,
      orderingDraft: _draft,
    );
    _syncTicker();
  }

  void _commit(QuestionOutcome outcome) {
    _outcomes.add(outcome);
    if (_outcomes.length == definition.questionCount) {
      _finish(QuizCompletionReason.questionsFinished);
      return;
    }
    if (definition is QuickPlayQuizDefinition) _remaining = null;
    _state = QuizFeedback(
      index: _index,
      outcome: outcome,
      remaining: _remaining,
    );
    _resetBaseline();
    _syncTicker();
    _emit();
  }

  bool get _counting =>
      timingEnabled &&
      (_state is QuizAnswering ||
          (definition is DailyQuizDefinition && _state is QuizFeedback));

  void _resetBaseline() {
    _baselineElapsed = _clock.elapsed;
    _baselineUtc = _clock.utcNow;
  }

  void _reconcile() {
    if (_disposed || _terminal) return;
    final now = _clock.elapsed;
    final utc = _clock.utcNow;
    if (_counting && _baselineElapsed != null) {
      var delta = now - _baselineElapsed!;
      if (delta < Duration.zero) delta = Duration.zero;
      if (!_visible) {
        final wallDelta = utc.difference(_baselineUtc!);
        if (wallDelta > delta) delta = wallDelta;
      }
      _remaining = _remaining! > delta ? _remaining! - delta : Duration.zero;
    }
    // One baseline for every app/route/tick/action signal: no overlapping charge.
    _baselineElapsed = now;
    _baselineUtc = utc;
    if (_counting && _remaining == Duration.zero) {
      _expire();
    } else {
      _refreshState();
    }
  }

  void _expire() {
    if (definition is QuickPlayQuizDefinition) {
      _commit(QuestionOutcome.timedOut(definition.questions[_index]));
      return;
    }
    if (_state is QuizAnswering) {
      _outcomes.add(QuestionOutcome.timedOut(definition.questions[_index]));
    }
    for (var i = _outcomes.length; i < definition.questionCount; i++) {
      _outcomes.add(
        QuestionOutcome.unanswered(
          definition.questions[i],
          UnansweredReason.notReached,
        ),
      );
    }
    _finish(QuizCompletionReason.dailyTimeExpired);
  }

  void _refreshState() {
    if (_state is QuizAnswering) {
      _state = QuizAnswering(
        index: _index,
        question: definition.questions[_index],
        remaining: _remaining,
        orderingDraft: _draft,
      );
    } else if (_state is QuizFeedback) {
      _state = QuizFeedback(
        index: _index,
        outcome: _outcomes.last,
        remaining: _remaining,
      );
    }
  }

  void setAppActive(bool active) {
    if (_disposed || _terminal || _appActive == active) return;
    _reconcile();
    _appActive = active;
    _syncTicker();
    _emit();
  }

  void setRouteVisible(bool visible) {
    if (_disposed || _terminal || _routeVisible == visible) return;
    _reconcile();
    _routeVisible = visible;
    _syncTicker();
    _emit();
  }

  void _syncTicker() {
    _stopTicker();
    if (_disposed || _terminal || !_visible || !_counting) return;
    final generation = _tickerGeneration;
    _cancelTicker = _scheduler.schedule(() {
      if (_disposed || _terminal || generation != _tickerGeneration) return;
      _reconcile();
      _emit();
    });
  }

  void _stopTicker() {
    _tickerGeneration++;
    _cancelTicker?.call();
    _cancelTicker = null;
  }

  void _finish(QuizCompletionReason reason) {
    if (_disposed || _terminal) return;
    final result = QuizResult(
      completionId: completionId,
      definition: definition,
      timingEnabled: timingEnabled,
      completedAt: _clock.utcNow,
      reason: reason,
      outcomes: _outcomes,
    );
    _terminal = true;
    _state = QuizCompleted(result, QuizCompletionDelivery.pending);
    _release();
    // Future.sync invokes the sink now, after locking, before listeners can pop
    // the route. Its work is not cancelled when this controller is disposed.
    unawaited(
      Future<void>.sync(() => _completionSink(result)).then(
        (_) {
          if (_disposed) return;
          _state = QuizCompleted(result, QuizCompletionDelivery.delivered);
          _emit();
        },
        onError: (Object error, StackTrace stack) {
          if (_disposed) return;
          _state = QuizCompleted(
            result,
            QuizCompletionDelivery.failed,
            deliveryError: error,
          );
          _emit();
        },
      ),
    );
    _emit();
  }

  void abandon() {
    if (_disposed || _terminal) return;
    _reconcile();
    if (_terminal) return;
    _terminal = true;
    _state = const QuizAbandoned();
    _release();
    _emit();
  }

  void interrupt(Object cause) {
    if (_disposed || _terminal) return;
    _terminal = true;
    _state = QuizInterrupted(cause);
    _release();
    _emit();
  }

  void _cancelPreparation() {
    final attempt = _attempt;
    _attempt = null;
    if (attempt != null) _cleanup(attempt.cancel);
  }

  void _release() {
    _stopTicker();
    _preparationGeneration++;
    _cancelPreparation();
    final resources = _resources;
    _resources = null;
    if (resources != null) _cleanup(resources.release);
  }

  void _cleanup(void Function() callback) {
    try {
      callback();
    } catch (error) {
      if (kDebugMode) {
        debugPrint(
          '[QuizSessionController] cleanup failed: ${error.runtimeType}',
        );
      }
    }
  }

  void _emit() {
    if (_disposed) return;
    _notificationDepth++;
    try {
      notifyListeners();
    } finally {
      _notificationDepth--;
      // Resource cancellation is immediate; ChangeNotifier's listener storage
      // can only be disposed after an in-progress notification unwinds.
      if (_disposed && _notificationDepth == 0) super.dispose();
    }
  }

  @override
  void dispose() {
    if (_disposed) return;
    _disposed = true;
    _release();
    if (_notificationDepth == 0) super.dispose();
  }
}
