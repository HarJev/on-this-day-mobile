import 'package:flutter/foundation.dart';

import '../../../core/api/api_exception.dart';
import '../../../core/config/timezone_provider.dart';
import '../domain/daily_content.dart';
import '../domain/on_this_day_exceptions.dart';
import '../domain/on_this_day_repository.dart';

sealed class HomeState {
  const HomeState();
}

class HomeLoading extends HomeState {
  const HomeLoading();
}

class HomeLoaded extends HomeState {
  const HomeLoaded(this.content);

  final DailyContent content;
}

class HomeUnavailable extends HomeState {
  const HomeUnavailable({required this.message}) : assert(message != '');

  final String message;
}

class HomeError extends HomeState {
  const HomeError({required this.message}) : assert(message != '');

  final String message;
}

class HomeController extends ChangeNotifier {
  HomeController({
    required OnThisDayRepository repository,
    required TimezoneProvider timezoneProvider,
  }) : _repository = repository,
       _timezoneProvider = timezoneProvider;

  final OnThisDayRepository _repository;
  final TimezoneProvider _timezoneProvider;

  HomeState _state = const HomeLoading();
  HomeState get state => _state;

  Future<void> loadToday() async {
    _setState(const HomeLoading());

    final String timezone;
    try {
      _debugLog('timezone_lookup_start');
      timezone = await _timezoneProvider.currentTimezone();
      _debugLog('timezone_lookup_success timezone=$timezone');
    } catch (error) {
      _debugLog(
        'timezone_lookup_failure causeType=${error.runtimeType} cause=$error',
      );
      _setState(const HomeError(message: "Could not load today's history."));
      return;
    }

    try {
      _debugLog('repository_getTodayContent_start timezone=$timezone');
      final content = await _repository.getTodayContent(timezone);
      _debugLog('repository_getTodayContent_success');
      _setState(HomeLoaded(content));
    } on TodayContentUnavailableException {
      _debugLog('repository_getTodayContent_unavailable');
      _setState(
        const HomeUnavailable(
          message: "Today's history is unavailable right now.",
        ),
      );
    } on ApiException catch (error) {
      _debugLog(
        'api_exception kind=${error.kind} status=${error.statusCode} '
        'code=${error.code} causeType=${error.cause.runtimeType} '
        'cause=${error.cause}',
      );
      _setState(const HomeError(message: "Could not load today's history."));
    } catch (error) {
      _debugLog(
        'repository_getTodayContent_failure causeType=${error.runtimeType} '
        'cause=$error',
      );
      _setState(const HomeError(message: "Could not load today's history."));
    }
  }

  Future<void> retry() {
    return loadToday();
  }

  void _setState(HomeState state) {
    _state = state;
    notifyListeners();
  }

  void _debugLog(String message) {
    if (kDebugMode) {
      debugPrint('[HomeController] $message');
    }
  }
}
