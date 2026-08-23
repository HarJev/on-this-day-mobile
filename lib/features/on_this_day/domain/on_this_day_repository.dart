import 'daily_content.dart';
import 'historical_event.dart';

abstract interface class OnThisDayRepository {
  Future<DailyContent> getTodayContent(String timezone);

  Future<HistoricalEvent> getEvent(String eventId);
}
