import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:on_this_day_mobile/core/api/api_client.dart';
import 'package:on_this_day_mobile/core/api/api_exception.dart';
import 'package:on_this_day_mobile/features/on_this_day/data/backend_on_this_day_repository.dart';
import 'package:on_this_day_mobile/features/on_this_day/domain/on_this_day_exceptions.dart';

void main() {
  group('BackendOnThisDayRepository', () {
    test('loads today content using the supplied timezone', () async {
      late Uri capturedUri;
      final repository = _repository((request) async {
        capturedUri = request.url;
        return http.Response(_todayResponse, 200);
      });

      final content = await repository.getTodayContent('America/Jamaica');

      expect(
        capturedUri.toString(),
        'http://127.0.0.1:3000/v1/days/today?timezone=America%2FJamaica',
      );
      expect(content.displayDate, 'Aug 24');
      expect(content.featuredEvent.id, 'burning-of-washington-1814');
      expect(content.featuredEvent.image?.sourceUrl, isNotNull);
      expect(content.additionalEvents.single.id, 'vesuvius-erupts-79');
    });

    test('maps invalid timezone to retryable API failure', () async {
      final repository = _repository(
        (_) async => http.Response(
          '{"code":"invalid_timezone","message":"Invalid timezone."}',
          400,
        ),
      );

      await expectLater(
        repository.getTodayContent('Invalid/Timezone'),
        throwsA(
          isA<ApiException>()
              .having((error) => error.statusCode, 'statusCode', 400)
              .having((error) => error.code, 'code', 'invalid_timezone'),
        ),
      );
    });

    test('maps content unavailable to domain exception', () async {
      final repository = _repository(
        (_) async => http.Response(
          '{"code":"content_unavailable","message":"Content unavailable."}',
          503,
        ),
      );

      await expectLater(
        repository.getTodayContent('America/Jamaica'),
        throwsA(isA<TodayContentUnavailableException>()),
      );
    });

    test('loads event detail by event ID', () async {
      late Uri capturedUri;
      final repository = _repository((request) async {
        capturedUri = request.url;
        return http.Response(_eventDetailResponse, 200);
      });

      final event = await repository.getEvent('burning-of-washington-1814');

      expect(
        capturedUri.toString(),
        'http://127.0.0.1:3000/v1/events/burning-of-washington-1814',
      );
      expect(event.id, 'burning-of-washington-1814');
      expect(event.sources.single.name, 'White House Historical Association');
      expect(event.primaryImage?.sourceUrl, isNotNull);
      expect(event.images.single.sourceUrl, isNotNull);
    });

    test('maps event not found to domain exception', () async {
      final repository = _repository(
        (_) async => http.Response(
          '{"code":"event_not_found","message":"Event not found."}',
          404,
        ),
      );

      await expectLater(
        repository.getEvent('missing-event'),
        throwsA(
          isA<EventNotFoundException>().having(
            (error) => error.eventId,
            'eventId',
            'missing-event',
          ),
        ),
      );
    });
  });
}

BackendOnThisDayRepository _repository(
  Future<http.Response> Function(http.Request request) handler,
) {
  return BackendOnThisDayRepository(
    apiClient: ApiClient(
      baseUrl: Uri.parse('http://127.0.0.1:3000'),
      httpClient: MockClient(handler),
    ),
  );
}

const _imageJson = '''
{
  "url": "https://upload.wikimedia.org/example.jpg",
  "altText": "An archival illustration",
  "source": "Wikimedia Commons",
  "sourceUrl": "https://commons.wikimedia.org/wiki/File:Example.jpg",
  "attribution": "Example attribution",
  "creator": "Example creator",
  "license": "Public Domain Mark 1.0",
  "licenseUrl": "https://creativecommons.org/publicdomain/mark/1.0/"
}
''';

const _todayResponse =
    '''
{
  "date": {
    "month": 8,
    "day": 24,
    "displayDate": "Aug 24"
  },
  "featuredEvent": {
    "id": "burning-of-washington-1814",
    "title": "British forces burn Washington",
    "year": "1814",
    "historicalDate": "August 24, 1814",
    "summary": "British troops entered Washington during the War of 1812.",
    "notificationTitle": "Washington burned on this day",
    "notificationBody": "British forces set fire to public buildings in 1814.",
    "image": $_imageJson
  },
  "additionalEvents": [
    {
      "id": "vesuvius-erupts-79",
      "title": "Mount Vesuvius erupts",
      "year": "79",
      "historicalDate": "August 24, 79"
    }
  ]
}
''';

const _eventDetailResponse =
    '''
{
  "id": "burning-of-washington-1814",
  "title": "British forces burn Washington",
  "year": "1814",
  "historicalDate": "August 24, 1814",
  "summary": "British troops entered Washington during the War of 1812.",
  "description": "The attack damaged public buildings including the Capitol.",
  "sources": [
    {
      "name": "White House Historical Association",
      "url": "https://www.whitehousehistory.org/the-burning-of-washington"
    }
  ],
  "primaryImage": $_imageJson,
  "images": [$_imageJson]
}
''';
