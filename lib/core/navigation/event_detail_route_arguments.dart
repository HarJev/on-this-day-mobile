/// Optional arguments for the Event Detail route.
final class EventDetailRouteArguments {
  const EventDetailRouteArguments({this.isToday = false});

  /// Whether the event belongs to today's content, which today's Daily
  /// Challenge draws on. Past days only offer practice, so they carry no quiz
  /// link.
  final bool isToday;
}
