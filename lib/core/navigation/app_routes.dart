abstract final class AppRoutes {
  static const today = '/today';
  static const eventsPrefix = '/events';

  static String eventDetail(String eventId) => '$eventsPrefix/$eventId';
}
