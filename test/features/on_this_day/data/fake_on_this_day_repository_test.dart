import 'package:flutter_test/flutter_test.dart';
import 'package:on_this_day_mobile/features/on_this_day/data/fake_on_this_day_repository.dart';
import 'package:on_this_day_mobile/features/on_this_day/domain/on_this_day_exceptions.dart';

void main() {
  group('FakeOnThisDayRepository', () {
    test('returns curated daily content with one featured event', () async {
      final repository = FakeOnThisDayRepository();

      final content = await repository.getTodayContent('America/Jamaica');

      expect(content.displayDate, 'Aug 22');
      expect(content.featuredEvent.id, 'battle-of-bosworth-field-1485');
      expect(content.featuredEvent.notificationTitle, isNotEmpty);
      expect(content.featuredEvent.notificationBody, isNotEmpty);
      expect(content.additionalEvents, hasLength(6));
      expect(
        content.additionalEvents.map((event) => event.id).toSet(),
        hasLength(content.additionalEvents.length),
      );
    });

    test(
      'returns event details with sources and featured image metadata',
      () async {
        final repository = FakeOnThisDayRepository();

        final event = await repository.getEvent(
          'battle-of-bosworth-field-1485',
        );

        expect(event.sources, isNotEmpty);
        expect(event.sources.first.name, 'Encyclopaedia Britannica');
        expect(event.sources.first.url.scheme, 'https');
        expect(event.primaryImage, isNotNull);
        expect(event.primaryImage?.source, 'Wikimedia Commons');
        expect(event.primaryImage?.creator, 'Edmund Blair Leighton');
        expect(event.primaryImage?.license, 'Public Domain Mark 1.0');
        expect(event.primaryImage?.licenseUrl?.scheme, 'https');
      },
    );

    test('keeps at least one event without an image', () async {
      final repository = FakeOnThisDayRepository();

      final event = await repository.getEvent('loch-ness-monster-columba-565');

      expect(event.primaryImage, isNull);
      expect(event.images, isEmpty);
      expect(event.sources, isNotEmpty);
    });

    test('throws when an event is not found', () async {
      final repository = FakeOnThisDayRepository();

      expect(
        repository.getEvent('missing-event'),
        throwsA(isA<EventNotFoundException>()),
      );
    });
  });
}
