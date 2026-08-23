import 'package:flutter_test/flutter_test.dart';
import 'package:on_this_day_mobile/features/on_this_day/domain/daily_content.dart';
import 'package:on_this_day_mobile/features/on_this_day/domain/event_source.dart';
import 'package:on_this_day_mobile/features/on_this_day/domain/historical_event.dart';
import 'package:on_this_day_mobile/features/on_this_day/domain/on_this_day_exceptions.dart';
import 'package:on_this_day_mobile/features/on_this_day/domain/on_this_day_repository.dart';
import 'package:on_this_day_mobile/features/on_this_day/presentation/event_detail_controller.dart';

void main() {
  group('EventDetailController', () {
    test('starts in loading state without loading automatically', () {
      final repository = _RecordingRepository(result: _event);

      final controller = EventDetailController(
        repository: repository,
        eventId: 'event-1',
      );

      expect(controller.state, isA<EventDetailLoading>());
      expect(repository.loadCount, 0);
    });

    test('loads event successfully', () async {
      final repository = _RecordingRepository(result: _event);
      final controller = EventDetailController(
        repository: repository,
        eventId: 'event-1',
      );

      await controller.loadEvent();

      final state = controller.state;
      expect(state, isA<EventDetailLoaded>());
      expect((state as EventDetailLoaded).event, same(_event));
      expect(repository.lastEventId, 'event-1');
    });

    test('notifies listeners through loading and loaded states', () async {
      final repository = _RecordingRepository(result: _event);
      final controller = EventDetailController(
        repository: repository,
        eventId: 'event-1',
      );
      final states = <EventDetailState>[];
      controller.addListener(() => states.add(controller.state));

      await controller.loadEvent();

      expect(states, [isA<EventDetailLoading>(), isA<EventDetailLoaded>()]);
    });

    test('maps not found to unavailable state', () async {
      final repository = _RecordingRepository(
        exception: const EventNotFoundException('event-1'),
      );
      final controller = EventDetailController(
        repository: repository,
        eventId: 'event-1',
      );

      await controller.loadEvent();

      final state = controller.state;
      expect(state, isA<EventDetailUnavailable>());
      expect(
        (state as EventDetailUnavailable).message,
        'This event is unavailable.',
      );
    });

    test('maps unexpected failures to retryable error', () async {
      final repository = _RecordingRepository(exception: Exception('network'));
      final controller = EventDetailController(
        repository: repository,
        eventId: 'event-1',
      );

      await controller.loadEvent();

      final state = controller.state;
      expect(state, isA<EventDetailError>());
      expect((state as EventDetailError).message, 'Could not load this event.');
    });

    test('retry loads again and can recover from an error', () async {
      final repository = _SequenceRepository([Exception('network'), _event]);
      final controller = EventDetailController(
        repository: repository,
        eventId: 'event-1',
      );

      await controller.loadEvent();
      expect(controller.state, isA<EventDetailError>());

      await controller.retry();

      final state = controller.state;
      expect(state, isA<EventDetailLoaded>());
      expect((state as EventDetailLoaded).event, same(_event));
      expect(repository.loadCount, 2);
    });
  });
}

final _event = HistoricalEvent(
  id: 'event-1',
  title: 'A detailed historical event',
  year: '1485',
  historicalDate: 'August 22, 1485',
  summary: 'A concise summary.',
  description: 'A concise description of what happened and why it mattered.',
  sources: [
    EventSource(
      name: 'Example Source',
      url: Uri.parse('https://example.com/history'),
    ),
  ],
);

class _RecordingRepository implements OnThisDayRepository {
  _RecordingRepository({this.result, this.exception});

  final HistoricalEvent? result;
  final Object? exception;

  int loadCount = 0;
  String? lastEventId;

  @override
  Future<DailyContent> getTodayContent(String timezone) {
    throw UnimplementedError();
  }

  @override
  Future<HistoricalEvent> getEvent(String eventId) async {
    loadCount += 1;
    lastEventId = eventId;

    final exception = this.exception;
    if (exception != null) {
      throw exception;
    }

    return result!;
  }
}

class _SequenceRepository implements OnThisDayRepository {
  _SequenceRepository(this.results);

  final List<Object> results;

  int loadCount = 0;

  @override
  Future<DailyContent> getTodayContent(String timezone) {
    throw UnimplementedError();
  }

  @override
  Future<HistoricalEvent> getEvent(String eventId) async {
    final result = results[loadCount];
    loadCount += 1;

    if (result is Exception) {
      throw result;
    }

    return result as HistoricalEvent;
  }
}
