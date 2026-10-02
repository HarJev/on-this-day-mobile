import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:on_this_day_mobile/core/config/app_theme.dart';
import 'package:on_this_day_mobile/core/images/cached_optional_image_loader.dart';
import 'package:on_this_day_mobile/core/images/image_request_cancellation.dart';
import 'package:on_this_day_mobile/core/navigation/source_launcher.dart';
import 'package:on_this_day_mobile/features/on_this_day/domain/event_image.dart';
import 'package:on_this_day_mobile/features/on_this_day/domain/featured_event.dart';
import 'package:on_this_day_mobile/features/on_this_day/presentation/widgets/event_image_credit.dart';
import 'package:on_this_day_mobile/features/on_this_day/presentation/widgets/featured_event_card.dart';

import '../../quiz/support/image_fakes.dart';

void main() {
  group('summaryFor', () {
    test('names the creator and licence', () {
      expect(
        EventImageCredit.summaryFor(_image),
        'Image: Jane Doe · CC BY-SA 4.0',
      );
    });

    test('falls back to attribution, then source', () {
      expect(
        EventImageCredit.summaryFor(
          _imageWith(attribution: 'Photograph by Elliott & Fry'),
        ),
        'Image: Photograph by Elliott & Fry · CC BY-SA 4.0',
      );
      expect(
        EventImageCredit.summaryFor(
          EventImage(
            url: _imageUrl,
            altText: 'A portrait',
            source: 'Wikimedia Commons',
            license: 'Public Domain Mark 1.0',
          ),
        ),
        'Image: Wikimedia Commons · Public Domain Mark 1.0',
      );
    });

    test('is null when there is nothing to credit', () {
      expect(
        EventImageCredit.summaryFor(
          EventImage(url: _imageUrl, altText: 'A portrait', creator: '  '),
        ),
        isNull,
      );
    });
  });

  testWidgets('featured card shows a credit line once the image loads', (
    tester,
  ) async {
    await _pumpCard(tester, loader: await _loadedLoader(tester));

    expect(find.text('Image: Jane Doe · CC BY-SA 4.0'), findsOneWidget);
    expect(
      tester.getSize(find.byKey(const Key('event-image-credit'))).height,
      greaterThanOrEqualTo(48),
    );
    expect(tester.takeException(), isNull);
  });

  testWidgets('featured portrait is contained without clipping its subject', (
    tester,
  ) async {
    final image = await tester.runAsync(
      () => testImage(width: 200, height: 410),
    );
    await _pumpCard(tester, loader: _FakeOptionalImageLoader.image(image!));

    expect(tester.widget<RawImage>(find.byType(RawImage)).fit, BoxFit.contain);
    expect(
      tester.widget<AspectRatio>(find.byType(AspectRatio)).aspectRatio,
      1.2,
    );
    expect(find.text('A featured event'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('no credit line when the image fails to load', (tester) async {
    await _pumpCard(tester, loader: _FakeOptionalImageLoader.failure());

    expect(find.byType(EventImageCredit), findsNothing);
    expect(find.text('A featured event'), findsOneWidget);
  });

  testWidgets('tapping the credit opens full provenance, not the event', (
    tester,
  ) async {
    final launcher = _RecordingSourceLauncher();
    var eventOpened = false;
    await _pumpCard(
      tester,
      loader: await _loadedLoader(tester),
      launcher: launcher,
      onTap: () => eventOpened = true,
    );

    await tester.tap(find.byKey(const Key('event-image-credit')));
    await tester.pumpAndSettle();

    expect(eventOpened, isFalse);
    expect(find.text('Image credit'), findsOneWidget);
    expect(find.text('Photo by Jane Doe'), findsOneWidget);
    expect(find.text('Creator: Jane Doe'), findsOneWidget);
    expect(find.text('Wikimedia Commons'), findsOneWidget);
    expect(find.text('CC BY-SA 4.0'), findsOneWidget);

    await tester.tap(find.text('CC BY-SA 4.0'));
    await tester.pump();
    expect(launcher.openedUrls, [_licenseUrl]);

    await tester.tap(find.text('Wikimedia Commons'));
    await tester.pump();
    expect(launcher.openedUrls, [_licenseUrl, _sourceUrl]);
  });

  testWidgets('credit announces itself as a button', (tester) async {
    final handle = tester.ensureSemantics();
    await _pumpCard(tester, loader: await _loadedLoader(tester));

    expect(
      find.bySemanticsLabel(
        'Image: Jane Doe · CC BY-SA 4.0. Show image credit',
      ),
      findsOneWidget,
    );
    handle.dispose();
  });
}

final _imageUrl = Uri.parse('https://example.org/portrait.jpg');
final _sourceUrl = Uri.parse('https://commons.wikimedia.org/wiki/File:X.jpg');
final _licenseUrl = Uri.parse(
  'https://creativecommons.org/licenses/by-sa/4.0/',
);

final _image = _imageWith(
  attribution: 'Photo by Jane Doe',
  creator: 'Jane Doe',
);

EventImage _imageWith({String? attribution, String? creator}) => EventImage(
  url: _imageUrl,
  altText: 'A portrait',
  source: 'Wikimedia Commons',
  sourceUrl: _sourceUrl,
  attribution: attribution,
  creator: creator,
  license: 'CC BY-SA 4.0',
  licenseUrl: _licenseUrl,
);

Future<OptionalImageLoader> _loadedLoader(WidgetTester tester) async {
  final image = await tester.runAsync(() => testImage(width: 410, height: 200));
  return _FakeOptionalImageLoader.image(image!);
}

Future<void> _pumpCard(
  WidgetTester tester, {
  required OptionalImageLoader loader,
  SourceLauncher? launcher,
  VoidCallback? onTap,
}) async {
  await tester.pumpWidget(
    MaterialApp(
      theme: AppTheme.light,
      home: Scaffold(
        body: ListView(
          children: [
            FeaturedEventCard(
              event: FeaturedEvent(
                id: 'event-1',
                title: 'A featured event',
                year: '1914',
                historicalDate: 'June 28, 1914',
                summary: 'A short summary.',
                notificationTitle: 'On this day',
                notificationBody: 'A featured event',
                image: _image,
              ),
              onTap: onTap ?? () {},
              imageLoader: loader,
              sourceLauncher: launcher ?? _RecordingSourceLauncher(),
            ),
          ],
        ),
      ),
    ),
  );
  await tester.runAsync(
    () async => Future<void>.delayed(const Duration(milliseconds: 100)),
  );
  await tester.pumpAndSettle();
}

final class _FakeOptionalImageLoader implements OptionalImageLoader {
  _FakeOptionalImageLoader(this._load);

  factory _FakeOptionalImageLoader.failure() =>
      _FakeOptionalImageLoader(() async => throw StateError('unavailable'));

  factory _FakeOptionalImageLoader.image(ui.Image image) =>
      _FakeOptionalImageLoader(() async => image.clone());

  final Future<ui.Image> Function() _load;

  @override
  Future<ui.Image> load(Uri url, ImageRequestCancellation cancellation) =>
      _load();
}

class _RecordingSourceLauncher implements SourceLauncher {
  final openedUrls = <Uri>[];

  @override
  Future<bool> open(Uri url) async {
    openedUrls.add(url);
    return true;
  }
}
