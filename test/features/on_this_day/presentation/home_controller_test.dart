import 'package:flutter_test/flutter_test.dart';
import 'package:on_this_day_mobile/core/config/timezone_provider.dart';
import 'package:on_this_day_mobile/features/on_this_day/domain/daily_content.dart';
import 'package:on_this_day_mobile/features/on_this_day/domain/featured_event.dart';
import 'package:on_this_day_mobile/features/on_this_day/domain/historical_event.dart';
import 'package:on_this_day_mobile/features/on_this_day/domain/on_this_day_exceptions.dart';
import 'package:on_this_day_mobile/features/on_this_day/domain/on_this_day_repository.dart';
import 'package:on_this_day_mobile/features/on_this_day/presentation/home_controller.dart';

void main() {
  group('HomeController', () {
    test('starts in loading state without loading automatically', () {
      final repository = _RecordingRepository(result: _dailyContent);

      final controller = HomeController(
        repository: repository,
        timezoneProvider: const _FixedTimezoneProvider('America/Jamaica'),
      );

      expect(controller.state, isA<HomeLoading>());
      expect(repository.loadCount, 0);
    });

    test('loads today content successfully', () async {
      final repository = _RecordingRepository(result: _dailyContent);
      final controller = HomeController(
        repository: repository,
        timezoneProvider: const _FixedTimezoneProvider('America/Jamaica'),
      );

      await controller.loadToday();

      final state = controller.state;
      expect(state, isA<HomeLoaded>());
      expect((state as HomeLoaded).content, same(_dailyContent));
      expect(repository.lastTimezone, 'America/Jamaica');
    });

    test('notifies listeners through loading and loaded states', () async {
      final repository = _RecordingRepository(result: _dailyContent);
      final controller = HomeController(
        repository: repository,
        timezoneProvider: const _FixedTimezoneProvider('America/Jamaica'),
      );
      final states = <HomeState>[];
      controller.addListener(() => states.add(controller.state));

      await controller.loadToday();

      expect(states, [isA<HomeLoading>(), isA<HomeLoaded>()]);
    });

    test('maps unavailable content to HomeUnavailable', () async {
      final repository = _RecordingRepository(
        exception: const TodayContentUnavailableException(),
      );
      final controller = HomeController(
        repository: repository,
        timezoneProvider: const _FixedTimezoneProvider('America/Jamaica'),
      );

      await controller.loadToday();

      final state = controller.state;
      expect(state, isA<HomeUnavailable>());
      expect(
        (state as HomeUnavailable).message,
        "Today's history is unavailable right now.",
      );
    });

    test('maps unexpected failures to retryable HomeError', () async {
      final repository = _RecordingRepository(exception: Exception('network'));
      final controller = HomeController(
        repository: repository,
        timezoneProvider: const _FixedTimezoneProvider('America/Jamaica'),
      );

      await controller.loadToday();

      final state = controller.state;
      expect(state, isA<HomeError>());
      expect((state as HomeError).message, "Could not load today's history.");
    });

    test('retry loads again and can recover from an error', () async {
      final repository = _SequenceRepository([
        Exception('network'),
        _dailyContent,
      ]);
      final controller = HomeController(
        repository: repository,
        timezoneProvider: const _FixedTimezoneProvider('America/Jamaica'),
      );

      await controller.loadToday();
      expect(controller.state, isA<HomeError>());

      await controller.retry();

      final state = controller.state;
      expect(state, isA<HomeLoaded>());
      expect((state as HomeLoaded).content, same(_dailyContent));
      expect(repository.loadCount, 2);
    });

    test('maps timezone lookup failures to retryable HomeError', () async {
      final repository = _RecordingRepository(result: _dailyContent);
      final controller = HomeController(
        repository: repository,
        timezoneProvider: _ThrowingTimezoneProvider(Exception('timezone')),
      );

      await controller.loadToday();

      final state = controller.state;
      expect(state, isA<HomeError>());
      expect((state as HomeError).message, "Could not load today's history.");
      expect(repository.loadCount, 0);
    });
  });
}

const _featuredEvent = FeaturedEvent(
  id: 'battle-of-bosworth-field-1485',
  title: 'Richard III is defeated at the Battle of Bosworth Field',
  year: '1485',
  historicalDate: 'August 22, 1485',
  summary: 'The battle ended the Wars of the Roses.',
  notificationTitle: 'A king died in battle 541 years ago today',
  notificationBody: "Richard III's defeat at Bosworth changed England forever.",
);

const _dailyContent = DailyContent(
  displayDate: 'Aug 22',
  featuredEvent: _featuredEvent,
  additionalEvents: [],
);

class _RecordingRepository implements OnThisDayRepository {
  _RecordingRepository({this.result, this.exception});

  final DailyContent? result;
  final Object? exception;

  int loadCount = 0;
  String? lastTimezone;

  @override
  Future<DailyContent> getTodayContent(String timezone) async {
    loadCount += 1;
    lastTimezone = timezone;

    final exception = this.exception;
    if (exception != null) {
      throw exception;
    }

    return result!;
  }

  @override
  Future<HistoricalEvent> getEvent(String eventId) {
    throw UnimplementedError();
  }
}

class _SequenceRepository implements OnThisDayRepository {
  _SequenceRepository(this.results);

  final List<Object> results;

  int loadCount = 0;

  @override
  Future<DailyContent> getTodayContent(String timezone) async {
    final result = results[loadCount];
    loadCount += 1;

    if (result is Exception) {
      throw result;
    }

    return result as DailyContent;
  }

  @override
  Future<HistoricalEvent> getEvent(String eventId) {
    throw UnimplementedError();
  }
}

class _FixedTimezoneProvider implements TimezoneProvider {
  const _FixedTimezoneProvider(this.timezone);

  final String timezone;

  @override
  Future<String> currentTimezone() async {
    return timezone;
  }
}

class _ThrowingTimezoneProvider implements TimezoneProvider {
  const _ThrowingTimezoneProvider(this.exception);

  final Object exception;

  @override
  Future<String> currentTimezone() async {
    throw exception;
  }
}
