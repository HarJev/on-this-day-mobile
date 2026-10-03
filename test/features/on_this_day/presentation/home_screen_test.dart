import 'dart:async';
import 'dart:ui' as ui;

import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:on_this_day_mobile/core/config/timezone_provider.dart';
import 'package:on_this_day_mobile/core/config/app_theme.dart';
import 'package:on_this_day_mobile/core/images/cached_optional_image_loader.dart';
import 'package:on_this_day_mobile/core/images/image_request_cancellation.dart';
import 'package:on_this_day_mobile/features/on_this_day/domain/daily_content.dart';
import 'package:on_this_day_mobile/features/on_this_day/domain/featured_event.dart';
import 'package:on_this_day_mobile/features/on_this_day/domain/event_image.dart';
import 'package:on_this_day_mobile/features/on_this_day/domain/historical_event.dart';
import 'package:on_this_day_mobile/features/on_this_day/domain/historical_event_summary.dart';
import 'package:on_this_day_mobile/features/on_this_day/domain/on_this_day_exceptions.dart';
import 'package:on_this_day_mobile/features/on_this_day/domain/on_this_day_repository.dart';
import 'package:on_this_day_mobile/features/on_this_day/domain/recent_day.dart';
import 'package:on_this_day_mobile/features/on_this_day/presentation/home_screen.dart';
import 'package:on_this_day_mobile/features/on_this_day/presentation/widgets/featured_event_card.dart';

import '../../quiz/support/image_fakes.dart';

void main() {
  testWidgets('renders loading while today content is pending', (
    WidgetTester tester,
  ) async {
    final repository = _PendingRepository();

    await tester.pumpWidget(_homeApp(repository));

    expect(find.bySemanticsLabel("Loading today's history"), findsOneWidget);
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

  testWidgets('pulling down refreshes Today without hiding current content', (
    WidgetTester tester,
  ) async {
    final repository = _ControlledRefreshRepository();
    await tester.pumpWidget(_homeApp(repository));
    await tester.pump();

    await tester.timedDrag(
      find.byType(SingleChildScrollView).first,
      const Offset(0, 500),
      const Duration(milliseconds: 600),
    );
    await tester.pump(const Duration(seconds: 1));

    expect(repository.loadCount, 2);
    expect(find.text('Featured history'), findsOneWidget);
    expect(find.byType(RefreshProgressIndicator), findsOneWidget);

    repository.completeRefresh();
    await tester.pumpAndSettle();

    expect(find.text('Aug 23'), findsOneWidget);
    expect(find.text('Featured history'), findsOneWidget);
  });

  testWidgets('iOS refresh uses the native spinner', (tester) async {
    final repository = _ControlledRefreshRepository();
    await tester.pumpWidget(_homeApp(repository, platform: TargetPlatform.iOS));
    await tester.pump();

    await tester.timedDrag(
      find.byType(SingleChildScrollView),
      const Offset(0, 500),
      const Duration(milliseconds: 600),
    );
    await tester.pump(const Duration(seconds: 1));

    expect(repository.loadCount, 2);
    expect(find.byType(CupertinoActivityIndicator), findsOneWidget);
    expect(find.byType(RefreshProgressIndicator), findsNothing);

    repository.completeRefresh();
    await tester.pumpAndSettle();
  });

  testWidgets('fast fling keeps featured image and reaches recent days', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(390, 780);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    final image = (await tester.runAsync(
      () => testImage(width: 400, height: 300),
    ))!;
    addTearDown(image.dispose);
    final loader = _CountingImageLoader(image);
    final content = DailyContent(
      displayDate: 'Oct 3',
      featuredEvent: FeaturedEvent(
        id: 'featured-event',
        title: 'Featured history',
        year: '1485',
        historicalDate: 'August 22, 1485',
        summary: 'A concise featured summary.',
        notificationTitle: 'A curiosity-driven notification',
        notificationBody: 'A short notification body.',
        image: EventImage(
          url: Uri.parse('https://example.com/portrait.jpg'),
          altText: 'Historical portrait',
        ),
      ),
      additionalEvents: List.generate(
        5,
        (index) => HistoricalEventSummary(
          id: 'additional-$index',
          title: 'Additional history $index with a longer title',
          year: '19$index',
          historicalDate: 'October 3, 19$index',
        ),
      ),
    );
    final recentDays = List.generate(
      6,
      (index) => RecentDay(
        daysAgo: index + 1,
        displayDate: index < 2 ? 'Oct ${2 - index}' : 'Sep ${32 - index}',
        featuredEvent: HistoricalEventSummary(
          id: 'recent-$index',
          title: 'Recent history $index',
          year: '19$index',
          historicalDate: 'October 2, 19$index',
        ),
      ),
    );
    await tester.pumpWidget(
      _homeApp(
        _StaticRepository(content, recentDays: recentDays),
        imageLoader: loader,
        platform: TargetPlatform.iOS,
      ),
    );
    await tester.pumpAndSettle();
    expect(loader.loadCount, 1);

    final scrollable = find.byType(SingleChildScrollView);
    await tester.fling(scrollable, const Offset(0, -650), 5000);
    await tester.pumpAndSettle();

    final position = tester
        .state<ScrollableState>(find.byType(Scrollable))
        .position;
    expect(position.extentAfter, lessThan(1));
    expect(find.byType(FeaturedEventCard, skipOffstage: false), findsOneWidget);
    expect(loader.loadCount, 1);

    await tester.fling(scrollable, const Offset(0, 650), 5000);
    await tester.pumpAndSettle();
    expect(loader.loadCount, 1);
  });

  testWidgets('renders recent days and opens their events', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(
      _homeApp(_StaticRepository(_dailyContent, recentDays: _recentDays)),
    );
    await tester.pump();
    await tester.pump();

    expect(find.text('Recent days'), findsOneWidget);
    await tester.scrollUntilVisible(
      find.textContaining('Daguerreotype history'),
      200,
    );
    expect(find.text('Yesterday'), findsOneWidget);
    expect(find.textContaining('Hawaii history'), findsOneWidget);
    expect(find.text('Aug 19'), findsOneWidget);

    await tester.tap(find.textContaining('Daguerreotype history'));
    await tester.pumpAndSettle();

    expect(find.text('Route: /events/daguerreotype-event'), findsOneWidget);
    expect(find.text('Arguments: null'), findsOneWidget);
  });

  testWidgets('hides recent days when there are none', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(_homeApp(_StaticRepository(_dailyContent)));
    await tester.pump();
    await tester.pump();

    expect(find.text('Recent days'), findsNothing);
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
    expect(
      find.text("Arguments: Instance of 'EventDetailRouteArguments'"),
      findsOneWidget,
    );
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
    expect(find.text('Try again'), findsOneWidget);
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

    await tester.tap(find.text('Try again'));
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
  OptionalImageLoader? imageLoader,
  TargetPlatform? platform,
}) {
  return MaterialApp(
    theme: AppTheme.light.copyWith(platform: platform),
    home: HomeScreen(
      repository: repository,
      timezoneProvider: const _FixedTimezoneProvider('Etc/UTC'),
      onShowDebugNotification: onShowDebugNotification,
      imageLoader: imageLoader,
    ),
    onGenerateRoute: (settings) {
      return MaterialPageRoute<void>(
        builder: (_) => Scaffold(
          body: Column(
            children: [
              Text('Route: ${settings.name}'),
              Text('Arguments: ${settings.arguments}'),
            ],
          ),
        ),
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

const _recentDays = [
  RecentDay(
    daysAgo: 1,
    displayDate: 'Aug 21',
    featuredEvent: HistoricalEventSummary(
      id: 'hawaii-event',
      title: 'Hawaii history',
      year: '1959',
      historicalDate: 'August 21, 1959',
    ),
  ),
  RecentDay(
    daysAgo: 3,
    displayDate: 'Aug 19',
    featuredEvent: HistoricalEventSummary(
      id: 'daguerreotype-event',
      title: 'Daguerreotype history',
      year: '1839',
      historicalDate: 'August 19, 1839',
    ),
  ),
];

const _dailyContentEmpty = DailyContent(
  displayDate: 'Aug 22',
  featuredEvent: _featuredEvent,
  additionalEvents: [],
);

class _ControlledRefreshRepository implements OnThisDayRepository {
  final Completer<DailyContent> _refresh = Completer<DailyContent>();
  int loadCount = 0;

  void completeRefresh() => _refresh.complete(
    const DailyContent(
      displayDate: 'Aug 23',
      featuredEvent: _featuredEvent,
      additionalEvents: [_additionalEvent],
    ),
  );

  @override
  Future<DailyContent> getTodayContent(String timezone) {
    loadCount += 1;
    return loadCount == 1 ? Future.value(_dailyContent) : _refresh.future;
  }

  @override
  Future<List<RecentDay>> getRecentDays(String timezone) async => const [];

  @override
  Future<HistoricalEvent> getEvent(String eventId) {
    throw UnimplementedError();
  }
}

class _PendingRepository implements OnThisDayRepository {
  final Completer<DailyContent> _completer = Completer<DailyContent>();

  String? lastTimezone;

  @override
  Future<DailyContent> getTodayContent(String timezone) {
    lastTimezone = timezone;
    return _completer.future;
  }

  @override
  Future<List<RecentDay>> getRecentDays(String timezone) async => const [];

  @override
  Future<HistoricalEvent> getEvent(String eventId) {
    throw UnimplementedError();
  }
}

class _StaticRepository implements OnThisDayRepository {
  const _StaticRepository(this.content, {this.recentDays = const []});

  final DailyContent content;
  final List<RecentDay> recentDays;

  @override
  Future<List<RecentDay>> getRecentDays(String timezone) async => recentDays;

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
  Future<List<RecentDay>> getRecentDays(String timezone) async => const [];

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
  Future<List<RecentDay>> getRecentDays(String timezone) async => const [];

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

final class _CountingImageLoader implements OptionalImageLoader {
  _CountingImageLoader(this.image);

  final ui.Image image;
  int loadCount = 0;

  @override
  Future<ui.Image> load(Uri url, ImageRequestCancellation cancellation) async {
    loadCount++;
    return image.clone();
  }
}
