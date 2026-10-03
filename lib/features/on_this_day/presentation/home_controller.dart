import 'package:flutter/foundation.dart';

import '../../../core/api/api_exception.dart';
import '../../../core/config/timezone_provider.dart';
import '../domain/daily_content.dart';
import '../domain/on_this_day_exceptions.dart';
import '../domain/on_this_day_repository.dart';
import '../domain/recent_day.dart';

sealed class HomeState {
  const HomeState();
}

class HomeLoading extends HomeState {
  const HomeLoading();
}

class HomeLoaded extends HomeState {
  const HomeLoaded(this.content, {this.recentDays = const []});

  final DailyContent content;

  /// Featured events of the previous six dates, newest first. Empty until
  /// they load, and stays empty if they cannot be loaded.
  final List<RecentDay> recentDays;
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
  int _loadGeneration = 0;
  bool _disposed = false;

  Future<void> refresh() => loadToday(showLoading: false);

  Future<void> loadToday({bool showLoading = true}) async {
    final generation = ++_loadGeneration;
    if (showLoading) _setState(const HomeLoading());

    final String timezone;
    try {
      _debugLog('timezone_lookup_start');
      timezone = await _timezoneProvider.currentTimezone();
      _debugLog('timezone_lookup_success timezone=$timezone');
    } catch (error) {
      if (_disposed || generation != _loadGeneration) return;
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
      if (_disposed || generation != _loadGeneration) return;
      _setState(HomeLoaded(content));
      await _loadRecentDays(timezone, generation);
    } on TodayContentUnavailableException {
      if (_disposed || generation != _loadGeneration) return;
      _debugLog('repository_getTodayContent_unavailable');
      _setState(
        const HomeUnavailable(
          message: "Today's history is unavailable right now.",
        ),
      );
    } on ApiException catch (error) {
      if (_disposed || generation != _loadGeneration) return;
      _debugLog(
        'api_exception kind=${error.kind} status=${error.statusCode} '
        'code=${error.code} causeType=${error.cause.runtimeType} '
        'cause=${error.cause}',
      );
      _setState(const HomeError(message: "Could not load today's history."));
    } catch (error) {
      if (_disposed || generation != _loadGeneration) return;
      _debugLog(
        'repository_getTodayContent_failure causeType=${error.runtimeType} '
        'cause=$error',
      );
      _setState(const HomeError(message: "Could not load today's history."));
    }
  }

  /// Recent days are secondary: a failure leaves Today as it is.
  Future<void> _loadRecentDays(String timezone, int generation) async {
    try {
      final recentDays = await _repository.getRecentDays(timezone);
      final current = _state;
      if (recentDays.isEmpty ||
          generation != _loadGeneration ||
          current is! HomeLoaded) {
        return;
      }
      _setState(HomeLoaded(current.content, recentDays: recentDays));
    } catch (error) {
      _debugLog(
        'repository_getRecentDays_failure causeType=${error.runtimeType} '
        'cause=$error',
      );
    }
  }

  Future<void> retry() {
    return loadToday();
  }

  /// A late result or timeout can arrive after the screen has gone, for
  /// example when a new day rebuilds Today mid-load.
  void _setState(HomeState state) {
    if (_disposed) return;
    _state = state;
    notifyListeners();
  }

  @override
  void dispose() {
    _disposed = true;
    super.dispose();
  }

  void _debugLog(String message) {
    if (kDebugMode) {
      debugPrint('[HomeController] $message');
    }
  }
}
