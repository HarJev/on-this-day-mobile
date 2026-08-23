import 'package:flutter/foundation.dart';

import '../domain/historical_event.dart';
import '../domain/on_this_day_exceptions.dart';
import '../domain/on_this_day_repository.dart';

sealed class EventDetailState {
  const EventDetailState();
}

class EventDetailLoading extends EventDetailState {
  const EventDetailLoading();
}

class EventDetailLoaded extends EventDetailState {
  const EventDetailLoaded(this.event);

  final HistoricalEvent event;
}

class EventDetailUnavailable extends EventDetailState {
  const EventDetailUnavailable({required this.message}) : assert(message != '');

  final String message;
}

class EventDetailError extends EventDetailState {
  const EventDetailError({required this.message}) : assert(message != '');

  final String message;
}

class EventDetailController extends ChangeNotifier {
  EventDetailController({
    required OnThisDayRepository repository,
    required String eventId,
  }) : assert(eventId != ''),
       _repository = repository,
       _eventId = eventId;

  final OnThisDayRepository _repository;
  final String _eventId;

  EventDetailState _state = const EventDetailLoading();
  EventDetailState get state => _state;

  Future<void> loadEvent() async {
    _setState(const EventDetailLoading());

    try {
      final event = await _repository.getEvent(_eventId);
      _setState(EventDetailLoaded(event));
    } on EventNotFoundException {
      _setState(
        const EventDetailUnavailable(message: 'This event is unavailable.'),
      );
    } catch (_) {
      _setState(const EventDetailError(message: 'Could not load this event.'));
    }
  }

  Future<void> retry() {
    return loadEvent();
  }

  void _setState(EventDetailState state) {
    _state = state;
    notifyListeners();
  }
}
