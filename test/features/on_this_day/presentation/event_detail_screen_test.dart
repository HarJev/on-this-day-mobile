import 'dart:async';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:on_this_day_mobile/core/config/app_theme.dart';
import 'package:on_this_day_mobile/core/images/cached_optional_image_loader.dart';
import 'package:on_this_day_mobile/core/images/image_request_cancellation.dart';
import 'package:on_this_day_mobile/core/navigation/source_launcher.dart';
import 'package:on_this_day_mobile/features/on_this_day/domain/daily_content.dart';
import 'package:on_this_day_mobile/features/on_this_day/domain/event_image.dart';
import 'package:on_this_day_mobile/features/on_this_day/domain/event_source.dart';
import 'package:on_this_day_mobile/features/on_this_day/domain/historical_event.dart';
import 'package:on_this_day_mobile/features/on_this_day/domain/on_this_day_exceptions.dart';
import 'package:on_this_day_mobile/features/on_this_day/domain/on_this_day_repository.dart';
import 'package:on_this_day_mobile/features/on_this_day/presentation/event_detail_screen.dart';

import '../../quiz/support/image_fakes.dart';

void main() {
  testWidgets('renders loading while event content is pending', (
    WidgetTester tester,
  ) async {
    final repository = _PendingRepository();

    await tester.pumpWidget(_detailApp(repository: repository));

    expect(find.text('Loading event...'), findsOneWidget);
    expect(repository.lastEventId, 'event-1');
  });

  testWidgets('renders loaded event detail content and sources', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(_detailApp());
    await tester.pump();

    expect(find.text('On This Day'), findsOneWidget);
    expect(find.text('AUGUST 22, 1485'), findsOneWidget);
    expect(find.text('A detailed historical event'), findsOneWidget);
    expect(
      find.text('A concise description of what happened and why it mattered.'),
      findsOneWidget,
    );
    expect(find.text('READ MORE'), findsOneWidget);
    expect(find.text('Example Source'), findsOneWidget);
  });

  testWidgets('renders unavailable state when event is not found', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(
      _detailApp(
        repository: _ThrowingRepository(
          const EventNotFoundException('event-1'),
        ),
      ),
    );
    await tester.pump();

    expect(find.text('This event is unavailable.'), findsOneWidget);
    expect(find.text('Retry'), findsOneWidget);
  });

  testWidgets('renders retryable error and recovers on retry', (
    WidgetTester tester,
  ) async {
    final repository = _SequenceRepository([Exception('network'), _event]);

    await tester.pumpWidget(_detailApp(repository: repository));
    await tester.pump();

    expect(find.text('Could not load this event.'), findsOneWidget);

    await tester.tap(find.text('Retry'));
    await tester.pumpAndSettle();

    expect(find.text('A detailed historical event'), findsOneWidget);
    expect(repository.loadCount, 2);
  });

  testWidgets('source tap opens exact URL with launcher', (
    WidgetTester tester,
  ) async {
    final launcher = _RecordingSourceLauncher(openResult: true);

    await tester.pumpWidget(_detailApp(sourceLauncher: launcher));
    await tester.pump();

    await tester.ensureVisible(find.text('Example Source'));
    await tester.pump();
    await tester.tap(find.text('Example Source'));
    await tester.pump();

    expect(launcher.openedUrls, [Uri.parse('https://example.com/history')]);
    expect(find.text('Could not open source.'), findsNothing);
  });

  testWidgets('failed source launch shows a message', (
    WidgetTester tester,
  ) async {
    final launcher = _RecordingSourceLauncher(openResult: false);

    await tester.pumpWidget(_detailApp(sourceLauncher: launcher));
    await tester.pump();

    await tester.ensureVisible(find.text('Example Source'));
    await tester.pump();
    await tester.tap(find.text('Example Source'));
    await tester.pump();

    expect(find.text('Could not open source.'), findsOneWidget);
  });

  testWidgets('no-image event renders without an image placeholder', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(_detailApp());
    await tester.pump();

    expect(find.byType(Image), findsNothing);
    expect(find.text('A detailed historical event'), findsOneWidget);
    expect(find.text('AUGUST 22, 1485'), findsOneWidget);
  });

  testWidgets('image credit sits under the image and opens the licence', (
    WidgetTester tester,
  ) async {
    final image = await tester.runAsync(
      () => testImage(width: 410, height: 200),
    );
    final launcher = _RecordingSourceLauncher();
    final licenseUrl = Uri.parse(
      'https://creativecommons.org/licenses/by-sa/4.0/',
    );
    await tester.pumpWidget(
      _detailApp(
        repository: _StaticRepository(
          HistoricalEvent(
            id: _event.id,
            title: _event.title,
            year: _event.year,
            historicalDate: _event.historicalDate,
            summary: _event.summary,
            description: _event.description,
            sources: _event.sources,
            primaryImage: EventImage(
              url: Uri.parse('https://example.org/battle.jpg'),
              altText: 'A battle scene',
              source: 'Wikimedia Commons',
              sourceUrl: Uri.parse('https://commons.wikimedia.org/wiki/X'),
              creator: 'Jane Doe',
              license: 'CC BY-SA 4.0',
              licenseUrl: licenseUrl,
            ),
          ),
        ),
        sourceLauncher: launcher,
        imageLoader: _ImageLoader(image!),
      ),
    );
    await tester.runAsync(
      () async => Future<void>.delayed(const Duration(milliseconds: 100)),
    );
    await tester.pumpAndSettle();

    final credit = find.text('Image: Jane Doe · CC BY-SA 4.0');
    expect(credit, findsOneWidget);
    expect(
      tester.getTopLeft(credit).dy,
      lessThan(tester.getTopLeft(find.text(_event.description)).dy),
    );

    await tester.ensureVisible(credit);
    await tester.pumpAndSettle();
    await tester.tap(credit);
    await tester.pumpAndSettle();
    await tester.tap(find.text('CC BY-SA 4.0'));
    await tester.pump();

    expect(launcher.openedUrls, [licenseUrl]);
    expect(tester.takeException(), isNull);
  });
}

Widget _detailApp({
  OnThisDayRepository? repository,
  SourceLauncher? sourceLauncher,
  OptionalImageLoader? imageLoader,
}) {
  return MaterialApp(
    theme: AppTheme.light,
    home: EventDetailScreen(
      repository: repository ?? _StaticRepository(_event),
      eventId: 'event-1',
      sourceLauncher: sourceLauncher ?? _RecordingSourceLauncher(),
      imageLoader: imageLoader,
    ),
  );
}

final _event = HistoricalEvent(
  id: 'event-1',
  title: 'A detailed historical event',
  year: '1485',
  historicalDate: 'August 22, 1485',
  summary: 'A concise summary.',
  description: 'A concise description of what happened and why it mattered.',
  sources: [
    EventSource(
      name: 'Example Source',
      url: Uri.parse('https://example.com/history'),
    ),
  ],
);

class _PendingRepository implements OnThisDayRepository {
  final Completer<HistoricalEvent> _completer = Completer<HistoricalEvent>();

  String? lastEventId;

  @override
  Future<DailyContent> getTodayContent(String timezone) {
    throw UnimplementedError();
  }

  @override
  Future<HistoricalEvent> getEvent(String eventId) {
    lastEventId = eventId;
    return _completer.future;
  }
}

class _StaticRepository implements OnThisDayRepository {
  const _StaticRepository(this.event);

  final HistoricalEvent event;

  @override
  Future<DailyContent> getTodayContent(String timezone) {
    throw UnimplementedError();
  }

  @override
  Future<HistoricalEvent> getEvent(String eventId) async {
    return event;
  }
}

class _ThrowingRepository implements OnThisDayRepository {
  const _ThrowingRepository(this.exception);

  final Object exception;

  @override
  Future<DailyContent> getTodayContent(String timezone) {
    throw UnimplementedError();
  }

  @override
  Future<HistoricalEvent> getEvent(String eventId) async {
    throw exception;
  }
}

class _SequenceRepository implements OnThisDayRepository {
  _SequenceRepository(this.results);

  final List<Object> results;

  int loadCount = 0;

  @override
  Future<DailyContent> getTodayContent(String timezone) {
    throw UnimplementedError();
  }

  @override
  Future<HistoricalEvent> getEvent(String eventId) async {
    final result = results[loadCount];
    loadCount += 1;

    if (result is Exception) {
      throw result;
    }

    return result as HistoricalEvent;
  }
}

class _RecordingSourceLauncher implements SourceLauncher {
  _RecordingSourceLauncher({this.openResult = true});

  final bool openResult;
  final List<Uri> openedUrls = [];

  @override
  Future<bool> open(Uri url) async {
    openedUrls.add(url);
    return openResult;
  }
}

final class _ImageLoader implements OptionalImageLoader {
  _ImageLoader(this.image);

  final ui.Image image;

  @override
  Future<ui.Image> load(Uri url, ImageRequestCancellation cancellation) async =>
      image.clone();
}
