import '../../domain/historical_event_summary.dart';
import 'api_json.dart';

class ApiHistoricalEventSummaryResponse {
  const ApiHistoricalEventSummaryResponse({
    required this.id,
    required this.title,
    required this.year,
    required this.historicalDate,
    this.dateNote,
  });

  factory ApiHistoricalEventSummaryResponse.fromJson(
    Map<String, Object?> json,
  ) {
    return ApiHistoricalEventSummaryResponse(
      id: requiredString(json, 'id'),
      title: requiredString(json, 'title'),
      year: requiredString(json, 'year'),
      historicalDate: requiredString(json, 'historicalDate'),
      dateNote: optionalString(json, 'dateNote'),
    );
  }

  final String id;
  final String title;
  final String year;
  final String historicalDate;
  final String? dateNote;

  HistoricalEventSummary toDomain() {
    return HistoricalEventSummary(
      id: id,
      title: title,
      year: year,
      historicalDate: historicalDate,
      dateNote: dateNote,
    );
  }
}
