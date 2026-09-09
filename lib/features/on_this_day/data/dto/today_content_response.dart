import '../../domain/daily_content.dart';
import 'api_featured_event_response.dart';
import 'api_historical_event_summary_response.dart';
import 'api_json.dart';

class TodayContentResponse {
  const TodayContentResponse({
    required this.displayDate,
    required this.featuredEvent,
    required this.additionalEvents,
  });

  factory TodayContentResponse.fromJson(Map<String, Object?> json) {
    final date = requiredObject(json, 'date');

    return TodayContentResponse(
      displayDate: requiredString(date, 'displayDate'),
      featuredEvent: ApiFeaturedEventResponse.fromJson(
        requiredObject(json, 'featuredEvent'),
      ),
      additionalEvents: requiredObjectList(
        json,
        'additionalEvents',
      ).map(ApiHistoricalEventSummaryResponse.fromJson).toList(growable: false),
    );
  }

  final String displayDate;
  final ApiFeaturedEventResponse featuredEvent;
  final List<ApiHistoricalEventSummaryResponse> additionalEvents;

  DailyContent toDomain() {
    return DailyContent(
      displayDate: displayDate,
      featuredEvent: featuredEvent.toDomain(),
      additionalEvents: additionalEvents
          .map((event) => event.toDomain())
          .toList(growable: false),
    );
  }
}
