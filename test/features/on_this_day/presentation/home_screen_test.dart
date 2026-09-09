import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:on_this_day_mobile/core/config/timezone_provider.dart';
import 'package:on_this_day_mobile/core/config/app_theme.dart';
import 'package:on_this_day_mobile/features/on_this_day/domain/daily_content.dart';
import 'package:on_this_day_mobile/features/on_this_day/domain/featured_event.dart';
import 'package:on_this_day_mobile/features/on_this_day/domain/historical_event.dart';
import 'package:on_this_day_mobile/features/on_this_day/domain/historical_event_summary.dart';
import 'package:on_this_day_mobile/features/on_this_day/domain/on_this_day_exceptions.dart';
import 'package:on_this_day_mobile/features/on_this_day/domain/on_this_day_repository.dart';
import 'package:on_this_day_mobile/features/on_this_day/presentation/home_screen.dart';
import 'package:on_this_day_mobile/features/on_this_day/presentation/widgets/featured_event_card.dart';

void main() {
  testWidgets('renders loading while today content is pending', (
    WidgetTester tester,
  ) async {
    final repository = _PendingRepository();

    await tester.pumpWidget(_homeApp(repository));

    expect(find.text("Loading today's history..."), findsOneWidget);
    await tester.pump();
    expect(repository.lastTimezone, 'Etc/UTC');
  });

  testWidgets('renders loaded home content', (WidgetTester tester) async {
    await tester.pumpWidget(_homeApp(_StaticRepository(_dailyContent)));
    await tester.pump();

    expect(find.text('On This Day'), findsOneWidget);
    expect(find.text('Aug 22'), findsOneWidget);
    expect(find.text('1485'), findsOneWidget);
    expect(find.text('Featured history'), findsOneWidget);
    expect(find.text('A concise featured summary.'), findsOneWidget);
    expect(find.text('Also on this day'), findsOneWidget);
    expect(find.text('1770'), findsOneWidget);
    expect(find.text('Additional history'), findsOneWidget);
  });

  testWidgets('does not render a back button on home', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(_homeApp(_StaticRepository(_dailyContent)));
    await tester.pump();

    expect(find.byTooltip('Back'), findsNothing);
    expect(find.byIcon(Icons.arrow_back), findsNothing);
  });

  testWidgets('shows and invokes the optional debug notification action', (
    WidgetTester tester,
  ) async {
    var invocationCount = 0;

    await tester.pumpWidget(
      _homeApp(
        _StaticRepository(_dailyContent),
        onShowDebugNotification: () => invocationCount += 1,
      ),
    );
    await tester.pump();

    await tester.tap(find.byTooltip('Show test notification'));

    expect(invocationCount, 1);
  });

  testWidgets('featured event tap navigates to event detail route', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(_homeApp(_StaticRepository(_dailyContent)));
    await tester.pump();

    await tester.tap(find.text('Featured history'));
    await tester.pumpAndSettle();

    expect(find.text('Route: /events/featured-event'), findsOneWidget);
  });

  testWidgets('additional event tap navigates to event detail route', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(_homeApp(_StaticRepository(_dailyContent)));
    await tester.pump();

    await tester.tap(find.text('Additional history'));
    await tester.pumpAndSettle();

    expect(find.text('Route: /events/additional-event'), findsOneWidget);
  });

  testWidgets('renders unavailable state with retry action', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(
      _homeApp(_ThrowingRepository(const TodayContentUnavailableException())),
    );
    await tester.pump();

    expect(
      find.text("Today's history is unavailable right now."),
      findsOneWidget,
    );
    expect(find.text('Retry'), findsOneWidget);
  });

  testWidgets('renders retryable error and recovers on retry', (
    WidgetTester tester,
  ) async {
    final repository = _SequenceRepository([
      Exception('network'),
      _dailyContent,
    ]);

    await tester.pumpWidget(_homeApp(repository));
    await tester.pump();

    expect(find.text("Could not load today's history."), findsOneWidget);

    await tester.tap(find.text('Retry'));
    await tester.pumpAndSettle();

    expect(find.text('Featured history'), findsOneWidget);
    expect(repository.loadCount, 2);
  });

  testWidgets('omits additional events section when there are none', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(_homeApp(_StaticRepository(_dailyContentEmpty)));
    await tester.pump();

    expect(find.text('Featured history'), findsOneWidget);
    expect(find.text('Also on this day'), findsNothing);
  });

  testWidgets('featured card remains complete without an image', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.light,
        home: Scaffold(
          body: FeaturedEventCard(event: _featuredEvent, onTap: () {}),
        ),
      ),
    );

    expect(find.byType(Image), findsNothing);
    expect(find.text('Featured history'), findsOneWidget);
    expect(find.text('1485'), findsOneWidget);
    expect(find.text('A concise featured summary.'), findsOneWidget);
  });
}

Widget _homeApp(
  OnThisDayRepository repository, {
  VoidCallback? onShowDebugNotification,
}) {
  return MaterialApp(
    theme: AppTheme.light,
    home: HomeScreen(
      repository: repository,
      timezoneProvider: const _FixedTimezoneProvider('Etc/UTC'),
      onShowDebugNotification: onShowDebugNotification,
    ),
    onGenerateRoute: (settings) {
      return MaterialPageRoute<void>(
        builder: (_) => Scaffold(body: Text('Route: ${settings.name}')),
        settings: settings,
      );
    },
  );
}

const _featuredEvent = FeaturedEvent(
  id: 'featured-event',
  title: 'Featured history',
  year: '1485',
  historicalDate: 'August 22, 1485',
  summary: 'A concise featured summary.',
  notificationTitle: 'A curiosity-driven notification',
  notificationBody: 'A short notification body.',
);

const _additionalEvent = HistoricalEventSummary(
  id: 'additional-event',
  title: 'Additional history',
  year: '1770',
  historicalDate: 'August 22, 1770',
);

const _dailyContent = DailyContent(
  displayDate: 'Aug 22',
  featuredEvent: _featuredEvent,
  additionalEvents: [_additionalEvent],
);

const _dailyContentEmpty = DailyContent(
  displayDate: 'Aug 22',
  featuredEvent: _featuredEvent,
  additionalEvents: [],
);

class _PendingRepository implements OnThisDayRepository {
  final Completer<DailyContent> _completer = Completer<DailyContent>();

  String? lastTimezone;

  @override
  Future<DailyContent> getTodayContent(String timezone) {
    lastTimezone = timezone;
    return _completer.future;
  }

  @override
  Future<HistoricalEvent> getEvent(String eventId) {
    throw UnimplementedError();
  }
}

class _StaticRepository implements OnThisDayRepository {
  const _StaticRepository(this.content);

  final DailyContent content;

  @override
  Future<DailyContent> getTodayContent(String timezone) async {
    return content;
  }

  @override
  Future<HistoricalEvent> getEvent(String eventId) {
    throw UnimplementedError();
  }
}

class _ThrowingRepository implements OnThisDayRepository {
  const _ThrowingRepository(this.exception);

  final Object exception;

  @override
  Future<DailyContent> getTodayContent(String timezone) async {
    throw exception;
  }

  @override
  Future<HistoricalEvent> getEvent(String eventId) {
    throw UnimplementedError();
  }
}

class _SequenceRepository implements OnThisDayRepository {
  _SequenceRepository(this.results);

  final List<Object> results;

  int loadCount = 0;

  @override
  Future<DailyContent> getTodayContent(String timezone) async {
    final result = results[loadCount];
    loadCount += 1;

    if (result is Exception) {
      throw result;
    }

    return result as DailyContent;
  }

  @override
  Future<HistoricalEvent> getEvent(String eventId) {
    throw UnimplementedError();
  }
}

class _FixedTimezoneProvider implements TimezoneProvider {
  const _FixedTimezoneProvider(this.timezone);

  final String timezone;

  @override
  Future<String> currentTimezone() async {
    return timezone;
  }
}
