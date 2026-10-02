import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:on_this_day_mobile/core/images/cached_optional_image_loader.dart';
import 'package:on_this_day_mobile/core/images/image_request_cancellation.dart';
import 'package:on_this_day_mobile/features/on_this_day/presentation/widgets/optional_event_image.dart';

import '../../quiz/support/image_fakes.dart';

void main() {
  testWidgets('failed optional image leaves no frame or spacing', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Column(
          children: [
            OptionalEventImage(
              url: Uri.parse('https://example.org/unavailable.jpg'),
              altText: 'Unavailable archival image',
              loader: _FakeOptionalImageLoader.failure(),
              padding: const EdgeInsets.all(28),
            ),
            const Text('History remains readable'),
          ],
        ),
      ),
    );
    await tester.runAsync(
      () async => Future<void>.delayed(const Duration(milliseconds: 100)),
    );
    await tester.pumpAndSettle();
    expect(find.byType(AspectRatio), findsNothing);
    expect(find.text('History remains readable'), findsOneWidget);
    expect(tester.getSize(find.byType(OptionalEventImage)).height, 0);
    expect(tester.takeException(), isNull);
  });

  testWidgets('loaded image keeps its editorial frame and alt text', (
    tester,
  ) async {
    final image = await tester.runAsync(
      () => testImage(width: 410, height: 200),
    );
    await tester.pumpWidget(
      MaterialApp(
        home: OptionalEventImage(
          url: Uri.parse('https://example.org/archive.jpg'),
          altText: 'Archival portrait',
          loader: _FakeOptionalImageLoader.image(image!),
        ),
      ),
    );
    await tester.runAsync(
      () async => Future<void>.delayed(const Duration(milliseconds: 100)),
    );
    await tester.pumpAndSettle();
    expect(
      tester.widget<AspectRatio>(find.byType(AspectRatio)).aspectRatio,
      2.05,
    );
    expect(
      tester.getSemantics(find.byType(OptionalEventImage)).label,
      contains('Archival portrait'),
    );
    expect(tester.takeException(), isNull);
  });
  testWidgets('featured portrait shows its full frame instead of cropping', (
    tester,
  ) async {
    final image = await tester.runAsync(
      () => testImage(width: 200, height: 410),
    );
    await tester.pumpWidget(
      MaterialApp(
        home: OptionalEventImage(
          url: Uri.parse('https://example.org/portrait.jpg'),
          altText: 'Portrait of a historical figure',
          loader: _FakeOptionalImageLoader.image(image!),
          aspectRatio: 16 / 9.5,
          portraitAspectRatio: 1.2,
        ),
      ),
    );
    await tester.runAsync(
      () async => Future<void>.delayed(const Duration(milliseconds: 100)),
    );
    await tester.pumpAndSettle();

    expect(
      tester.widget<AspectRatio>(find.byType(AspectRatio)).aspectRatio,
      1.2,
    );
    expect(tester.widget<RawImage>(find.byType(RawImage)).fit, BoxFit.contain);
    expect(tester.takeException(), isNull);
  });
}

final class _FakeOptionalImageLoader implements OptionalImageLoader {
  _FakeOptionalImageLoader(this._load);

  factory _FakeOptionalImageLoader.failure() =>
      _FakeOptionalImageLoader((_) async => throw StateError('unavailable'));

  factory _FakeOptionalImageLoader.image(ui.Image image) =>
      _FakeOptionalImageLoader((_) async => image);

  final Future<ui.Image> Function(ImageRequestCancellation) _load;

  @override
  Future<ui.Image> load(Uri url, ImageRequestCancellation cancellation) =>
      _load(cancellation);
}
