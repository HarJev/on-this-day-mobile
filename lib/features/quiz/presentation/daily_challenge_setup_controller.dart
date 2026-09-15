import 'package:flutter/foundation.dart';

import '../../../core/config/timezone_provider.dart';
import '../application/daily_challenge_status.dart';
import '../application/quiz_completion_coordinator.dart';
import '../application/quiz_completion_id_generator.dart';
import '../application/quiz_session_launch_request.dart';
import '../domain/quiz_catalog.dart';
import '../domain/quiz_definition.dart';
import '../domain/quiz_exceptions.dart';
import '../domain/quiz_repository.dart';
import '../domain/quiz_result.dart';
import '../domain/quiz_result_store.dart';
import '../domain/quiz_rules.dart';

sealed class DailyChallengeSetupState {
  const DailyChallengeSetupState();
}

final class DailyChallengeSetupLoading extends DailyChallengeSetupState {
  const DailyChallengeSetupLoading();
}

final class DailyChallengeSetupEmpty extends DailyChallengeSetupState {
  const DailyChallengeSetupEmpty();
}

final class DailyChallengeSetupReady extends DailyChallengeSetupState {
  const DailyChallengeSetupReady(this.data);
  final DailyChallengeSetupData data;
}

final class DailyChallengeSetupStarting extends DailyChallengeSetupState {
  const DailyChallengeSetupStarting(this.data);
  final DailyChallengeSetupData data;
}

final class DailyChallengeSetupFailure extends DailyChallengeSetupState {
  const DailyChallengeSetupFailure({
    required this.message,
    required this.kind,
    this.data,
  });
  final String message;
  final QuizFailureKind kind;
  final DailyChallengeSetupData? data;
}

final class DailyChallengeSetupData {
  const DailyChallengeSetupData({
    required this.preview,
    required this.availability,
    required this.selectedQuestionCount,
    required this.status,
  });

  final DailyQuizDefinition preview;
  final QuizAvailability availability;
  final int selectedQuestionCount;
  final DailyChallengeStatus status;

  bool get selectedCountIsSupported =>
      availability.supportedQuestionCounts.contains(selectedQuestionCount);

  Duration? durationFor(int questionCount) =>
      QuizRules.dailyDefaults[questionCount];

  DailyChallengeSetupData copyWith({int? selectedQuestionCount}) =>
      DailyChallengeSetupData(
        preview: preview,
        availability: availability,
        selectedQuestionCount:
            selectedQuestionCount ?? this.selectedQuestionCount,
        status: status,
      );
}

/// Resolves a backend Daily date only after the user enters setup. It never
/// prepares images or starts a timer.
final class DailyChallengeSetupController extends ChangeNotifier {
  DailyChallengeSetupController({
    required QuizRepository repository,
    required TimezoneProvider timezoneProvider,
    required QuizResultStore resultStore,
    required QuizCompletionCoordinator completionCoordinator,
    required QuizCompletionIdGenerator completionIdGenerator,
    required QuizAvailability availability,
  }) : _repository = repository,
       _timezoneProvider = timezoneProvider,
       _resultStore = resultStore,
       _completionCoordinator = completionCoordinator,
       _completionIdGenerator = completionIdGenerator,
       _availability = availability,
       _selectedQuestionCount = availability.supportedQuestionCounts.contains(5)
           ? 5
           : availability.supportedQuestionCounts.firstOrNull;

  final QuizRepository _repository;
  final TimezoneProvider _timezoneProvider;
  final QuizResultStore _resultStore;
  final QuizCompletionCoordinator _completionCoordinator;
  final QuizCompletionIdGenerator _completionIdGenerator;
  final QuizAvailability _availability;
  int? _selectedQuestionCount;
  DailyChallengeSetupState _state = const DailyChallengeSetupLoading();
  DailyChallengeSetupState get state => _state;
  int _loadGeneration = 0;
  int _selectionGeneration = 0;
  bool _disposed = false;

  Future<void> load() async {
    final generation = ++_loadGeneration;
    if (_selectedQuestionCount == null) {
      _setState(const DailyChallengeSetupEmpty());
      return;
    }
    _setState(const DailyChallengeSetupLoading());
    try {
      final timezone = await _timezone();
      final preview = await _repository.getDaily(
        timezone: timezone,
        questionCount: _selectedQuestionCount!,
      );
      final status = await _statusFor(preview);
      if (!_isCurrentLoad(generation)) return;
      _setState(
        DailyChallengeSetupReady(
          DailyChallengeSetupData(
            preview: preview,
            availability: _availability,
            selectedQuestionCount: _selectedQuestionCount!,
            status: status,
          ),
        ),
      );
    } catch (error) {
      if (!_isCurrentLoad(generation)) return;
      final failure = _failure(error);
      _setState(
        DailyChallengeSetupFailure(
          message: failure.message,
          kind: failure.kind,
        ),
      );
    }
  }

  void selectQuestionCount(int questionCount) {
    if (!_availability.supportedQuestionCounts.contains(questionCount)) return;
    _selectedQuestionCount = questionCount;
    _selectionGeneration++;
    if (_state case DailyChallengeSetupReady(:final data)) {
      _setState(
        DailyChallengeSetupReady(
          data.copyWith(selectedQuestionCount: questionCount),
        ),
      );
    }
  }

  Future<QuizSessionLaunchRequest?> start() async {
    final current = _state;
    if (current is! DailyChallengeSetupReady ||
        !current.data.selectedCountIsSupported) {
      return null;
    }
    final selectionGeneration = _selectionGeneration;
    final requestedCount = current.data.selectedQuestionCount;
    _setState(DailyChallengeSetupStarting(current.data));
    DailyQuizDefinition? refreshedDefinition;
    try {
      final timezone = await _timezone();
      final definition = await _repository.getDaily(
        timezone: timezone,
        questionCount: requestedCount,
      );
      refreshedDefinition = definition;
      final status = await _statusFor(definition);
      if (!_canFinishStart(selectionGeneration, requestedCount)) return null;
      final data = DailyChallengeSetupData(
        preview: definition,
        availability: _availability,
        selectedQuestionCount: requestedCount,
        status: status,
      );
      _setState(DailyChallengeSetupReady(data));
      return QuizSessionLaunchRequest(
        definition: definition,
        completionId: _completionIdGenerator.nextId(),
        saveIntent: status.blocksOfficialClaim
            ? QuizSaveIntent.practice
            : QuizSaveIntent.claimDailyIfAbsent,
        timingEnabled: true,
      );
    } catch (error) {
      if (!_canFinishStart(selectionGeneration, requestedCount)) return null;
      final failure = _failure(error);
      _setState(
        DailyChallengeSetupFailure(
          message: failure.message,
          kind: failure.kind,
          data: refreshedDefinition == null
              ? current.data
              : DailyChallengeSetupData(
                  preview: refreshedDefinition,
                  availability: _availability,
                  selectedQuestionCount: requestedCount,
                  status: DailyChallengeStatus(
                    date: refreshedDefinition.date,
                    displayDate: refreshedDefinition.displayDate,
                  ),
                ),
        ),
      );
      return null;
    }
  }

  Future<DailyChallengeStatus> _statusFor(
    DailyQuizDefinition definition,
  ) async {
    final before = _completionCoordinator.dailyReservationFor(definition.date);
    final official = await _resultStore.getOfficialDaily(definition.date);
    final after = _completionCoordinator.dailyReservationFor(definition.date);
    if (official != null &&
        official.classification != QuizSavedClassification.official) {
      throw const QuizStorageException('Daily history is inconsistent.');
    }
    return DailyChallengeStatus(
      date: definition.date,
      displayDate: definition.displayDate,
      confirmedOfficialResult: official,
      reservation: after ?? before,
    );
  }

  _SetupFailure _failure(Object error) => switch (error) {
    QuizException(:final kind, :final message) => _SetupFailure(kind, message),
    _ => const _SetupFailure(
      QuizFailureKind.request,
      'Could not load the Daily Challenge. Please try again.',
    ),
  };

  Future<String> _timezone() async {
    try {
      final timezone = (await _timezoneProvider.currentTimezone()).trim();
      if (timezone.isEmpty) {
        throw const QuizException(
          QuizFailureKind.invalidTimezone,
          'Could not determine your timezone.',
        );
      }
      return timezone;
    } on QuizException {
      rethrow;
    } catch (error) {
      throw QuizException(
        QuizFailureKind.invalidTimezone,
        'Could not determine your timezone.',
        cause: error,
      );
    }
  }

  bool _isCurrentLoad(int generation) =>
      !_disposed && generation == _loadGeneration;

  bool _canFinishStart(int selectionGeneration, int questionCount) =>
      !_disposed &&
      selectionGeneration == _selectionGeneration &&
      questionCount == _selectedQuestionCount;

  void _setState(DailyChallengeSetupState state) {
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

final class _SetupFailure {
  const _SetupFailure(this.kind, this.message);
  final QuizFailureKind kind;
  final String message;
}
