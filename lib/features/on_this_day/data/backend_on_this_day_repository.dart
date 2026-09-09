import '../../../core/api/api_client.dart';
import '../../../core/api/api_exception.dart';
import '../domain/daily_content.dart';
import '../domain/historical_event.dart';
import '../domain/on_this_day_exceptions.dart';
import '../domain/on_this_day_repository.dart';
import 'dto/event_detail_response.dart';
import 'dto/today_content_response.dart';

class BackendOnThisDayRepository implements OnThisDayRepository {
  const BackendOnThisDayRepository({required ApiClient apiClient})
    : _apiClient = apiClient;

  final ApiClient _apiClient;

  @override
  Future<DailyContent> getTodayContent(String timezone) async {
    try {
      final json = await _apiClient.getJson(
        '/v1/days/today',
        queryParameters: {'timezone': timezone},
      );
      return TodayContentResponse.fromJson(json).toDomain();
    } on ApiException catch (error) {
      if (error.statusCode == 503 && error.code == 'content_unavailable') {
        throw const TodayContentUnavailableException();
      }
      rethrow;
    } on FormatException catch (error) {
      throw ApiException.invalidJson(cause: error);
    }
  }

  @override
  Future<HistoricalEvent> getEvent(String eventId) async {
    try {
      final json = await _apiClient.getJson(
        '/v1/events/${Uri.encodeComponent(eventId)}',
      );
      return EventDetailResponse.fromJson(json).toDomain();
    } on ApiException catch (error) {
      if (error.statusCode == 404 && error.code == 'event_not_found') {
        throw EventNotFoundException(eventId);
      }
      rethrow;
    } on FormatException catch (error) {
      throw ApiException.invalidJson(cause: error);
    }
  }
}
