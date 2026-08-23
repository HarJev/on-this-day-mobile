class TodayContentUnavailableException implements Exception {
  const TodayContentUnavailableException();

  @override
  String toString() => 'TodayContentUnavailableException';
}

class EventNotFoundException implements Exception {
  const EventNotFoundException(this.eventId);

  final String eventId;

  @override
  String toString() => 'EventNotFoundException: $eventId';
}
