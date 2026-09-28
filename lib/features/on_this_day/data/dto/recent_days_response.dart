import '../../domain/recent_day.dart';
import 'api_historical_event_summary_response.dart';
import 'api_json.dart';

class RecentDaysResponse {
  const RecentDaysResponse({required this.days});

  factory RecentDaysResponse.fromJson(Map<String, Object?> json) {
    return RecentDaysResponse(
      days: requiredObjectList(
        json,
        'days',
      ).map(ApiRecentDayResponse.fromJson).toList(growable: false),
    );
  }

  final List<ApiRecentDayResponse> days;

  List<RecentDay> toDomain() {
    return days.map((day) => day.toDomain()).toList(growable: false);
  }
}

class ApiRecentDayResponse {
  const ApiRecentDayResponse({
    required this.daysAgo,
    required this.displayDate,
    required this.featuredEvent,
  });

  factory ApiRecentDayResponse.fromJson(Map<String, Object?> json) {
    final daysAgo = json['daysAgo'];
    if (daysAgo is! int || daysAgo < 1) {
      throw const FormatException('Expected "daysAgo" to be a positive int.');
    }
    final date = requiredObject(json, 'date');

    return ApiRecentDayResponse(
      daysAgo: daysAgo,
      displayDate: requiredString(date, 'displayDate'),
      featuredEvent: ApiHistoricalEventSummaryResponse.fromJson(
        requiredObject(json, 'featuredEvent'),
      ),
    );
  }

  final int daysAgo;
  final String displayDate;
  final ApiHistoricalEventSummaryResponse featuredEvent;

  RecentDay toDomain() {
    return RecentDay(
      daysAgo: daysAgo,
      displayDate: displayDate,
      featuredEvent: featuredEvent.toDomain(),
    );
  }
}
