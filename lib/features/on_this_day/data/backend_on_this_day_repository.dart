import 'dart:async';

import '../../../core/api/api_client.dart';
import '../../../core/api/api_exception.dart';
import '../domain/daily_content.dart';
import '../domain/historical_event.dart';
import '../domain/on_this_day_exceptions.dart';
import '../domain/on_this_day_repository.dart';
import '../domain/recent_day.dart';
import 'dto/event_detail_response.dart';
import 'dto/recent_days_response.dart';
import 'dto/today_content_response.dart';

class BackendOnThisDayRepository implements OnThisDayRepository {
  BackendOnThisDayRepository({
    required ApiClient apiClient,
    Duration requestTimeout = const Duration(seconds: 20),
  }) : _apiClient = apiClient,
       _requestTimeout = requestTimeout {
    if (requestTimeout <= Duration.zero) {
      throw ArgumentError.value(
        requestTimeout,
        'requestTimeout',
        'Must be positive',
      );
    }
  }

  final ApiClient _apiClient;
  final Duration _requestTimeout;

  @override
  Future<DailyContent> getTodayContent(String timezone) async {
    try {
      final json = await _getJson(
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
      final json = await _getJson('/v1/events/${Uri.encodeComponent(eventId)}');
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

  @override
  Future<List<RecentDay>> getRecentDays(String timezone) async {
    try {
      final json = await _getJson(
        '/v1/days/recent',
        queryParameters: {'timezone': timezone, 'days': '7'},
      );
      return RecentDaysResponse.fromJson(json).toDomain();
    } on FormatException catch (error) {
      throw ApiException.invalidJson(cause: error);
    }
  }

  /// Bounds waiting only, matching Quiz: a stalled connection becomes a
  /// network failure the screens can offer to retry. The shared client stays
  /// open; a late response is ignored.
  Future<Map<String, Object?>> _getJson(
    String path, {
    Map<String, String> queryParameters = const {},
  }) async {
    try {
      return await _apiClient
          .getJson(path, queryParameters: queryParameters)
          .timeout(_requestTimeout);
    } on TimeoutException catch (error) {
      throw ApiException.network(cause: error);
    }
  }
}
