import 'package:flutter/foundation.dart';

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
    required String timezone,
  }) : assert(timezone != ''),
       _repository = repository,
       _timezone = timezone;

  final OnThisDayRepository _repository;
  final String _timezone;

  HomeState _state = const HomeLoading();
  HomeState get state => _state;

  Future<void> loadToday() async {
    _setState(const HomeLoading());

    try {
      final content = await _repository.getTodayContent(_timezone);
      _setState(HomeLoaded(content));
    } on TodayContentUnavailableException {
      _setState(
        const HomeUnavailable(
          message: "Today's history is unavailable right now.",
        ),
      );
    } catch (_) {
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
}
