import 'package:flutter/foundation.dart';

import '../application/quiz_completion_id_generator.dart';
import '../application/quiz_session_launch_request.dart';
import '../domain/quiz_catalog.dart';
import '../domain/quiz_definition.dart';
import '../domain/quiz_exceptions.dart';
import '../domain/quiz_repository.dart';
import '../domain/quiz_result.dart';
import '../domain/quiz_result_store.dart';

sealed class QuickPlaySetupState {
  const QuickPlaySetupState();
}

final class QuickPlaySetupLoading extends QuickPlaySetupState {
  const QuickPlaySetupLoading();
}

final class QuickPlaySetupReady extends QuickPlaySetupState {
  const QuickPlaySetupReady(this.data);
  final QuickPlaySetupData data;
}

final class QuickPlaySetupStarting extends QuickPlaySetupState {
  const QuickPlaySetupStarting(this.data);
  final QuickPlaySetupData data;
}

final class QuickPlaySetupFailure extends QuickPlaySetupState {
  const QuickPlaySetupFailure({required this.message, required this.kind});
  final String message;
  final QuizFailureKind kind;
}

final class QuickPlaySetupData {
  const QuickPlaySetupData({
    required this.catalog,
    required this.selectedQuestionCount,
    required this.timingEnabled,
    this.selectedCollectionId,
    this.preferenceError,
    this.preferenceSaving = false,
  });

  final QuizCatalog catalog;
  final String? selectedCollectionId;
  final int selectedQuestionCount;
  final bool timingEnabled;
  final String? preferenceError;
  final bool preferenceSaving;

  QuizAvailability get availability => selectedCollectionId == null
      ? catalog.mixed
      : catalog.collections
                .where((collection) => collection.id == selectedCollectionId)
                .singleOrNull
                ?.availability ??
            QuizAvailability(
              publishedQuestionCount: 0,
              supportedQuestionCounts: const [],
            );

  bool get selectedCountIsSupported =>
      availability.supportedQuestionCounts.contains(selectedQuestionCount);

  QuizCollection? get selectedCollection => selectedCollectionId == null
      ? null
      : catalog.collections
            .where((collection) => collection.id == selectedCollectionId)
            .singleOrNull;

  QuickPlaySetupData copyWith({
    String? selectedCollectionId,
    bool clearCollection = false,
    int? selectedQuestionCount,
    bool? timingEnabled,
    String? preferenceError,
    bool clearPreferenceError = false,
    bool? preferenceSaving,
  }) => QuickPlaySetupData(
    catalog: catalog,
    selectedCollectionId: clearCollection
        ? null
        : selectedCollectionId ?? this.selectedCollectionId,
    selectedQuestionCount: selectedQuestionCount ?? this.selectedQuestionCount,
    timingEnabled: timingEnabled ?? this.timingEnabled,
    preferenceError: clearPreferenceError
        ? null
        : preferenceError ?? this.preferenceError,
    preferenceSaving: preferenceSaving ?? this.preferenceSaving,
  );
}

/// Configures Quick Play but never creates a session controller or touches
/// image preparation. The returned launch request is consumed by a play route.
final class QuickPlaySetupController extends ChangeNotifier {
  QuickPlaySetupController({
    required QuizRepository repository,
    required QuizResultStore resultStore,
    required QuizCompletionIdGenerator completionIdGenerator,
    required QuizCatalog catalog,
  }) : _repository = repository,
       _resultStore = resultStore,
       _completionIdGenerator = completionIdGenerator,
       _catalog = catalog;

  final QuizRepository _repository;
  final QuizResultStore _resultStore;
  final QuizCompletionIdGenerator _completionIdGenerator;
  final QuizCatalog _catalog;
  QuickPlaySetupState _state = const QuickPlaySetupLoading();
  QuickPlaySetupState get state => _state;
  int _loadGeneration = 0;
  int _preferenceGeneration = 0;
  int _startGeneration = 0;
  bool _disposed = false;

  Future<void> load() async {
    final generation = ++_loadGeneration;
    _setState(const QuickPlaySetupLoading());
    try {
      final timingEnabled = await _resultStore.getQuickPlayTimingEnabled();
      if (!_isCurrentLoad(generation)) return;
      _setState(
        QuickPlaySetupReady(_initialData(timingEnabled: timingEnabled)),
      );
    } catch (_) {
      if (!_isCurrentLoad(generation)) return;
      _setState(
        QuickPlaySetupReady(
          _initialData(
            timingEnabled: true,
            preferenceError: 'Could not load the timing preference.',
          ),
        ),
      );
    }
  }

  void selectCollection(String? collectionId) {
    if (_state case QuickPlaySetupReady(:final data)) {
      if (collectionId != null &&
          !data.catalog.collections.any((item) => item.id == collectionId)) {
        return;
      }
      _setState(
        QuickPlaySetupReady(
          data.copyWith(
            selectedCollectionId: collectionId,
            clearCollection: collectionId == null,
          ),
        ),
      );
    }
  }

  void selectQuestionCount(int questionCount) {
    if (_state case QuickPlaySetupReady(:final data)) {
      _setState(
        QuickPlaySetupReady(
          data.copyWith(selectedQuestionCount: questionCount),
        ),
      );
    }
  }

  Future<void> setTimingEnabled(bool enabled) async {
    final current = _state;
    if (current is! QuickPlaySetupReady || current.data.preferenceSaving) {
      return;
    }
    final generation = ++_preferenceGeneration;
    _setState(
      QuickPlaySetupReady(
        current.data.copyWith(
          preferenceSaving: true,
          clearPreferenceError: true,
        ),
      ),
    );
    try {
      await _resultStore.setQuickPlayTimingEnabled(enabled);
      if (!_isCurrentPreference(generation)) return;
      final latest = _readyDataOrNull;
      if (latest == null) return;
      _setState(
        QuickPlaySetupReady(
          latest.copyWith(
            timingEnabled: enabled,
            preferenceSaving: false,
            clearPreferenceError: true,
          ),
        ),
      );
    } catch (_) {
      if (!_isCurrentPreference(generation)) return;
      final latest = _readyDataOrNull;
      if (latest == null) return;
      _setState(
        QuickPlaySetupReady(
          latest.copyWith(
            preferenceSaving: false,
            preferenceError: 'Could not save the timing preference.',
          ),
        ),
      );
    }
  }

  Future<QuizSessionLaunchRequest?> start() async {
    final current = _state;
    if (current is! QuickPlaySetupReady ||
        current.data.preferenceSaving ||
        !current.data.selectedCountIsSupported) {
      return null;
    }
    final generation = ++_startGeneration;
    final data = current.data;
    _setState(QuickPlaySetupStarting(data));
    try {
      final definition = await _repository.createQuickPlay(
        questionCount: data.selectedQuestionCount,
        collectionId: data.selectedCollectionId,
      );
      if (!_isCurrentStart(generation)) return null;
      _validateResponse(definition, data);
      _setState(QuickPlaySetupReady(data));
      return QuizSessionLaunchRequest(
        definition: definition,
        completionId: _completionIdGenerator.nextId(),
        saveIntent: QuizSaveIntent.quickPlay,
        timingEnabled: data.timingEnabled,
      );
    } catch (error) {
      if (!_isCurrentStart(generation)) return null;
      final failure = _failure(error);
      _setState(
        QuickPlaySetupFailure(message: failure.message, kind: failure.kind),
      );
      return null;
    }
  }

  QuickPlaySetupData _initialData({
    required bool timingEnabled,
    String? preferenceError,
  }) => QuickPlaySetupData(
    catalog: _catalog,
    selectedQuestionCount: 5,
    timingEnabled: timingEnabled,
    preferenceError: preferenceError,
  );

  void _validateResponse(
    QuickPlayQuizDefinition definition,
    QuickPlaySetupData data,
  ) {
    if (definition.questionCount != data.selectedQuestionCount ||
        definition.selection.collectionId != data.selectedCollectionId) {
      throw const QuizException(
        QuizFailureKind.invalidContent,
        'Quiz content could not be read. Please try again.',
      );
    }
  }

  _QuickFailure _failure(Object error) => switch (error) {
    QuizException(:final kind, :final message) => _QuickFailure(kind, message),
    _ => const _QuickFailure(
      QuizFailureKind.request,
      'Could not start Quick Play. Please try again.',
    ),
  };

  QuickPlaySetupData? get _readyDataOrNull => switch (_state) {
    QuickPlaySetupReady(:final data) => data,
    _ => null,
  };

  bool _isCurrentLoad(int generation) =>
      !_disposed && generation == _loadGeneration;

  bool _isCurrentPreference(int generation) =>
      !_disposed && generation == _preferenceGeneration;

  bool _isCurrentStart(int generation) =>
      !_disposed && generation == _startGeneration;

  void _setState(QuickPlaySetupState state) {
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

final class _QuickFailure {
  const _QuickFailure(this.kind, this.message);
  final QuizFailureKind kind;
  final String message;
}
