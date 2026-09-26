import 'dart:async';
import 'dart:collection';

import 'package:flutter_test/flutter_test.dart';
import 'package:on_this_day_mobile/core/config/timezone_provider.dart';
import 'package:on_this_day_mobile/features/quiz/application/quiz_completion_coordinator.dart';
import 'package:on_this_day_mobile/features/quiz/application/quiz_completion_id_generator.dart';
import 'package:on_this_day_mobile/features/quiz/domain/quiz_catalog.dart';
import 'package:on_this_day_mobile/features/quiz/domain/question_outcome.dart';
import 'package:on_this_day_mobile/features/quiz/domain/quiz_answer.dart';
import 'package:on_this_day_mobile/features/quiz/domain/quiz_definition.dart';
import 'package:on_this_day_mobile/features/quiz/domain/quiz_exceptions.dart';
import 'package:on_this_day_mobile/features/quiz/domain/quiz_question.dart';
import 'package:on_this_day_mobile/features/quiz/domain/quiz_repository.dart';
import 'package:on_this_day_mobile/features/quiz/domain/quiz_result.dart';
import 'package:on_this_day_mobile/features/quiz/domain/quiz_result_store.dart';
import 'package:on_this_day_mobile/features/quiz/domain/quiz_rules.dart';
import 'package:on_this_day_mobile/features/quiz/presentation/daily_challenge_setup_controller.dart';
import 'package:on_this_day_mobile/features/quiz/presentation/quick_play_setup_controller.dart';
import 'package:on_this_day_mobile/features/quiz/presentation/quiz_hub_controller.dart';

import '../support/session_fakes.dart';

void main() {
  group('QuizHubController', () {
    test('loads catalog without resolving a Daily definition', () async {
      final repository = _FakeQuizRepository(catalog: _catalog());
      final controller = QuizHubController(repository);

      await controller.load();

      expect(controller.state, isA<QuizHubLoaded>());
      expect(repository.catalogCalls, 1);
      expect(repository.dailyCalls, isEmpty);
    });

    test('keeps an empty catalog distinct from a request failure', () async {
      final empty = QuizCatalog(
        mixed: _availability(0),
        collections: const [],
        quickPlayTimerDefaults: QuizRules.quickPlayDefaults,
      );
      final controller = QuizHubController(_FakeQuizRepository(catalog: empty));

      await controller.load();

      expect(controller.state, isA<QuizHubEmpty>());
    });
  });

  group('DailyChallengeSetupController', () {
    test(
      'loads only the default Daily count and uses its backend date',
      () async {
        final repository = _FakeQuizRepository(
          catalog: _catalog(),
          dailyDefinitions: [_daily(5, date: '2026-09-14')],
        );
        final controller = _dailyController(repository: repository);

        await controller.load();

        final state = controller.state as DailyChallengeSetupReady;
        expect(repository.dailyCalls, [('America/Jamaica', 5)]);
        expect(state.data.status.date.isoDate, '2026-09-14');
        expect(state.data.durationFor(5), const Duration(minutes: 2));
        expect(state.data.preview.duration, const Duration(seconds: 71));
      },
    );

    test(
      'rechecks the returned backend date before an official launch',
      () async {
        final store = _FakeResultStore()
          ..officialByDate[QuizDate('2026-09-15')] = _storedOfficial('saved');
        final repository = _FakeQuizRepository(
          catalog: _catalog(),
          dailyDefinitions: [
            _daily(5, date: '2026-09-14'),
            _daily(5, date: '2026-09-15'),
          ],
        );
        final controller = _dailyController(
          repository: repository,
          store: store,
        );

        await controller.load();
        final launch = await controller.start();

        expect(launch!.definition, isA<DailyQuizDefinition>());
        expect(
          (launch.definition as DailyQuizDefinition).date.isoDate,
          '2026-09-15',
        );
        expect(launch.saveIntent, QuizSaveIntent.practice);
        expect(store.officialLookups.map((date) => date.isoDate), [
          '2026-09-14',
          '2026-09-15',
        ]);
      },
    );

    test('turns a timezone lookup failure into invalid_timezone', () async {
      final timezone = _FakeTimezoneProvider()
        ..error = StateError('plugin unavailable');
      final controller = _dailyController(
        repository: _FakeQuizRepository(catalog: _catalog()),
        timezone: timezone,
      );

      await controller.load();

      final state = controller.state as DailyChallengeSetupFailure;
      expect(state.kind, QuizFailureKind.invalidTimezone);
      expect(state.message, 'Could not determine your timezone.');
    });

    test('rejects an empty timezone before making a Daily request', () async {
      final timezone = _FakeTimezoneProvider()..value = '  ';
      final repository = _FakeQuizRepository(catalog: _catalog());
      final controller = _dailyController(
        repository: repository,
        timezone: timezone,
      );

      await controller.load();

      expect(
        (controller.state as DailyChallengeSetupFailure).kind,
        QuizFailureKind.invalidTimezone,
      );
      expect(repository.dailyCalls, isEmpty);
    });

    test(
      'blocks an official start when local official history is unreadable',
      () async {
        final store = _FakeResultStore()
          ..officialError = const QuizStorageException('unreadable');
        final controller = _dailyController(
          repository: _FakeQuizRepository(
            catalog: _catalog(),
            dailyDefinitions: [_daily(5)],
          ),
          store: store,
        );

        await controller.load();

        expect(controller.state, isA<DailyChallengeSetupFailure>());
        expect(
          (controller.state as DailyChallengeSetupFailure).kind,
          QuizFailureKind.storage,
        );
      },
    );

    test(
      'uses an app-lifetime reservation after an asynchronous lookup',
      () async {
        final store = _ControlledOfficialStore();
        final coordinator = QuizCompletionCoordinator(store);
        final controller = _dailyController(
          repository: _FakeQuizRepository(
            catalog: _catalog(),
            dailyDefinitions: [_daily(5)],
          ),
          store: store,
          coordinator: coordinator,
        );
        final loading = controller.load();
        await store.lookupStarted.future;
        coordinator.complete(_completion('reserved'));
        store.resolveLookup(null);

        await loading;

        final state = controller.state as DailyChallengeSetupReady;
        expect(state.data.status.reservation, isNotNull);
        expect(state.data.status.blocksOfficialClaim, isTrue);
      },
    );

    test(
      'keeps a rollover backend date visible when its status lookup fails',
      () async {
        final store = _FakeResultStore();
        final controller = _dailyController(
          repository: _FakeQuizRepository(
            catalog: _catalog(),
            dailyDefinitions: [
              _daily(5, date: '2026-09-14'),
              _daily(5, date: '2026-09-15'),
            ],
          ),
          store: store,
        );
        await controller.load();
        store.officialError = const QuizStorageException('unreadable');

        expect(await controller.start(), isNull);

        final state = controller.state as DailyChallengeSetupFailure;
        expect(state.data!.status.date.isoDate, '2026-09-15');
      },
    );

    test('creates one ID only after one successful launch handoff', () async {
      final ids = _FakeIds();
      final repository = _FakeQuizRepository(
        catalog: _catalog(),
        dailyDefinitions: [_daily(5), _daily(5)],
      );
      final controller = _dailyController(repository: repository, ids: ids);
      await controller.load();

      final first = controller.start();
      final second = controller.start();
      final launch = await first;
      expect(await second, isNull);

      expect(launch!.completionId, 'completion-1');
      expect(ids.calls, 1);
      expect(repository.dailyCalls.length, 2);
    });
  });

  group('QuickPlaySetupController', () {
    test(
      'retains an invalid selected count after a collection change',
      () async {
        final controller = _quickController(
          catalog: _catalog(
            collections: [_collection('small', _availability(5))],
          ),
        );
        await controller.load();
        controller.selectCollection('small');

        final data = (controller.state as QuickPlaySetupReady).data;
        expect(data.selectedQuestionCount, 5);
        expect(data.selectedCountIsSupported, isTrue);
        controller.selectQuestionCount(10);
        expect(
          (controller.state as QuickPlaySetupReady)
              .data
              .selectedCountIsSupported,
          isFalse,
        );
        expect(await controller.start(), isNull);
      },
    );

    test('keeps catalog usable when a timing preference cannot load', () async {
      final store = _FakeResultStore()..timingReadError = StateError('disk');
      final controller = _quickController(store: store);

      await controller.load();

      final data = (controller.state as QuickPlaySetupReady).data;
      expect(data.timingEnabled, isTrue);
      expect(data.preferenceError, 'Could not load the timing preference.');
    });

    test('keeps a completed preference write when selection changes', () async {
      final store = _ControlledTimingStore();
      final controller = _quickController(
        store: store,
        catalog: _catalog(collections: [_collection('wars', _availability(5))]),
      );
      await controller.load();

      final saving = controller.setTimingEnabled(false);
      controller.selectCollection('wars');
      store.resolveTimingWrite();
      await saving;

      final data = (controller.state as QuickPlaySetupReady).data;
      expect(data.selectedCollectionId, 'wars');
      expect(data.timingEnabled, isFalse);
      expect(data.preferenceSaving, isFalse);
    });

    test(
      'does not generate an ID when backend selection is malformed',
      () async {
        final ids = _FakeIds();
        final repository = _FakeQuizRepository(
          catalog: _catalog(),
          quickDefinitions: [
            _quick(
              5,
              selection: QuizSelection(
                collectionId: 'unexpected',
                displayName: 'Unexpected',
              ),
            ),
          ],
        );
        final controller = _quickController(repository: repository, ids: ids);
        await controller.load();

        expect(await controller.start(), isNull);
        expect(ids.calls, 0);
        expect(controller.state, isA<QuickPlaySetupFailure>());
      },
    );
  });
}

DailyChallengeSetupController _dailyController({
  required _FakeQuizRepository repository,
  QuizAvailability? availability,
  TimezoneProvider? timezone,
  QuizResultStore? store,
  QuizCompletionCoordinator? coordinator,
  QuizCompletionIdGenerator? ids,
}) {
  final resultStore = store ?? _FakeResultStore();
  return DailyChallengeSetupController(
    repository: repository,
    timezoneProvider: timezone ?? _FakeTimezoneProvider(),
    resultStore: resultStore,
    completionCoordinator:
        coordinator ?? QuizCompletionCoordinator(resultStore),
    completionIdGenerator: ids ?? _FakeIds(),
    availability: availability ?? _availability(5),
  );
}

QuickPlaySetupController _quickController({
  _FakeQuizRepository? repository,
  QuizResultStore? store,
  QuizCompletionIdGenerator? ids,
  QuizCatalog? catalog,
}) => QuickPlaySetupController(
  repository: repository ?? _FakeQuizRepository(catalog: catalog ?? _catalog()),
  resultStore: store ?? _FakeResultStore(),
  completionIdGenerator: ids ?? _FakeIds(),
  catalog: catalog ?? _catalog(),
);

QuizCatalog _catalog({List<QuizCollection> collections = const []}) =>
    QuizCatalog(
      mixed: _availability(5),
      collections: collections,
      quickPlayTimerDefaults: QuizRules.quickPlayDefaults,
    );

QuizAvailability _availability(int count) => QuizAvailability(
  publishedQuestionCount: count,
  supportedQuestionCounts: [
    for (final supported in QuizRules.questionCounts)
      if (supported <= count) supported,
  ],
);

QuizCollection _collection(String id, QuizAvailability availability) =>
    QuizCollection(
      id: id,
      name: 'Collection $id',
      group: QuizCollectionGroup.topic,
      availability: availability,
    );

DailyQuizDefinition _daily(int count, {String date = '2026-09-14'}) =>
    DailyQuizDefinition(
      questionCount: count,
      questions: _questions(count),
      challengeId: 'challenge-$date',
      date: QuizDate(date),
      displayDate: 'Sep 14',
      duration: const Duration(seconds: 71),
    );

QuickPlayQuizDefinition _quick(int count, {required QuizSelection selection}) =>
    QuickPlayQuizDefinition(
      questionCount: count,
      questions: _questions(count),
      selection: selection,
      questionTimeLimits: {
        for (final question in _questions(count))
          question.id: const Duration(seconds: 20),
      },
      timingEnabledByDefault: true,
    );

List<QuizQuestion> _questions(int count) => [
  for (var index = 0; index < count; index++)
    sessionQuestion(index, QuizQuestionType.multipleChoice),
];

StoredQuizResult _storedOfficial(String id) =>
    StoredQuizResult(_completion(id).result, QuizSavedClassification.official);

QuizCompletion _completion(String id) {
  final definition = _daily(5);
  return QuizCompletion(
    QuizResult(
      completionId: id,
      definition: definition,
      timingEnabled: true,
      completedAt: DateTime.utc(2026, 9, 14),
      reason: QuizCompletionReason.questionsFinished,
      outcomes: [
        for (final question in definition.questions)
          QuestionOutcome.answered(question, OptionAnswer('a')),
      ],
    ),
    QuizSaveIntent.claimDailyIfAbsent,
  );
}

final class _FakeQuizRepository implements QuizRepository {
  _FakeQuizRepository({
    required this.catalog,
    List<DailyQuizDefinition> dailyDefinitions = const [],
    List<QuickPlayQuizDefinition> quickDefinitions = const [],
  }) : _dailyDefinitions = Queue.of(dailyDefinitions),
       _quickDefinitions = Queue.of(quickDefinitions);

  final QuizCatalog catalog;
  final Queue<DailyQuizDefinition> _dailyDefinitions;
  final Queue<QuickPlayQuizDefinition> _quickDefinitions;
  int catalogCalls = 0;
  final dailyCalls = <(String, int)>[];
  final quickCalls = <(int, String?)>[];

  @override
  Future<QuizCatalog> getCatalog() async {
    catalogCalls++;
    return catalog;
  }

  @override
  Future<DailyQuizDefinition> getDaily({
    required String timezone,
    required int questionCount,
  }) async {
    dailyCalls.add((timezone, questionCount));
    if (_dailyDefinitions.isEmpty) throw StateError('No Daily definition');
    return _dailyDefinitions.removeFirst();
  }

  @override
  Future<QuickPlayQuizDefinition> createQuickPlay({
    required int questionCount,
    String? collectionId,
  }) async {
    quickCalls.add((questionCount, collectionId));
    if (_quickDefinitions.isEmpty) throw StateError('No Quick definition');
    return _quickDefinitions.removeFirst();
  }
}

final class _FakeTimezoneProvider implements TimezoneProvider {
  Object? error;
  String value = 'America/Jamaica';
  @override
  Future<String> currentTimezone() async {
    if (error != null) throw error!;
    return value;
  }
}

class _FakeResultStore implements QuizResultStore {
  final officialByDate = <QuizDate, StoredQuizResult>{};
  final officialLookups = <QuizDate>[];
  Object? officialError;
  Object? timingReadError;
  bool timingEnabled = true;

  @override
  Future<StoredQuizResult?> getOfficialDaily(QuizDate date) async {
    officialLookups.add(date);
    if (officialError != null) throw officialError!;
    return officialByDate[date];
  }

  @override
  Future<bool> getQuickPlayTimingEnabled() async {
    if (timingReadError != null) throw timingReadError!;
    return timingEnabled;
  }

  @override
  Future<void> setQuickPlayTimingEnabled(bool enabled) async {
    timingEnabled = enabled;
  }

  @override
  Future<StoredQuizResult?> getBestResult(QuizBestResultKey key) async => null;

  @override
  Future<StoredQuizResult> saveCompletion(QuizCompletion completion) async =>
      StoredQuizResult(completion.result, QuizSavedClassification.official);
}

final class _ControlledOfficialStore extends _FakeResultStore {
  final lookupStarted = Completer<void>();
  final _lookup = Completer<StoredQuizResult?>();

  @override
  Future<StoredQuizResult?> getOfficialDaily(QuizDate date) {
    officialLookups.add(date);
    lookupStarted.complete();
    return _lookup.future;
  }

  void resolveLookup(StoredQuizResult? result) => _lookup.complete(result);
}

final class _ControlledTimingStore extends _FakeResultStore {
  final _write = Completer<void>();

  @override
  Future<void> setQuickPlayTimingEnabled(bool enabled) => _write.future;

  void resolveTimingWrite() => _write.complete();
}

final class _FakeIds implements QuizCompletionIdGenerator {
  int calls = 0;
  @override
  String nextId() => 'completion-${++calls}';
}
