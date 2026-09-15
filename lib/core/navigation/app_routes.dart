abstract final class AppRoutes {
  static const root = '/';
  static const today = '/today';
  static const eventsPrefix = '/events';
  static const dailySetup = '/quiz/daily-setup';
  static const quickPlaySetup = '/quiz/quick-play-setup';
  static const gameplay = '/quiz/gameplay';
  static const results = '/quiz/results';
  static const review = '/quiz/review';

  static String eventDetail(String eventId) => '$eventsPrefix/$eventId';
}
