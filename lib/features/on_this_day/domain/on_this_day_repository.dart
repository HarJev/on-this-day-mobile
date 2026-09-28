import 'daily_content.dart';
import 'historical_event.dart';
import 'recent_day.dart';

abstract interface class OnThisDayRepository {
  Future<DailyContent> getTodayContent(String timezone);

  Future<HistoricalEvent> getEvent(String eventId);

  /// Featured events of the six local dates before today, newest first.
  /// Dates without content are omitted.
  Future<List<RecentDay>> getRecentDays(String timezone);
}
