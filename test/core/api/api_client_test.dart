import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:on_this_day_mobile/core/api/api_client.dart';
import 'package:on_this_day_mobile/core/api/api_exception.dart';

void main() {
  group('ApiClient', () {
    test('builds URLs from base URL, path, and query parameters', () {
      final client = ApiClient(
        baseUrl: Uri.parse('http://127.0.0.1:3000'),
        httpClient: MockClient((_) async => http.Response('{}', 200)),
      );

      final uri = client.uriFor(
        '/v1/days/today',
        queryParameters: {'timezone': 'America/Jamaica'},
      );

      expect(
        uri.toString(),
        'http://127.0.0.1:3000/v1/days/today?timezone=America%2FJamaica',
      );
    });

    test('preserves a configured base path', () {
      final client = ApiClient(
        baseUrl: Uri.parse('https://api.example.test/prod'),
        httpClient: MockClient((_) async => http.Response('{}', 200)),
      );

      expect(
        client.uriFor('/v1/events/battle-of-bosworth-field-1485').toString(),
        'https://api.example.test/prod/v1/events/'
        'battle-of-bosworth-field-1485',
      );
    });

    test('throws ApiException for API error responses', () async {
      final client = ApiClient(
        baseUrl: Uri.parse('http://127.0.0.1:3000'),
        httpClient: MockClient(
          (_) async => http.Response(
            '{"code":"invalid_timezone","message":"Invalid timezone."}',
            400,
          ),
        ),
      );

      await expectLater(
        client.getJson('/v1/days/today'),
        throwsA(
          isA<ApiException>()
              .having((error) => error.statusCode, 'statusCode', 400)
              .having((error) => error.code, 'code', 'invalid_timezone'),
        ),
      );
    });

    test('sends JSON POST requests', () async {
      late http.Request capturedRequest;
      final client = ApiClient(
        baseUrl: Uri.parse('http://127.0.0.1:3000'),
        httpClient: MockClient((request) async {
          capturedRequest = request;
          return http.Response('{"registered":true}', 200);
        }),
      );

      final response = await client.postJson(
        '/v1/devices',
        body: {'token': 'fcm-token'},
      );

      expect(response['registered'], isTrue);
      expect(capturedRequest.method, 'POST');
      expect(
        capturedRequest.url.toString(),
        'http://127.0.0.1:3000/v1/devices',
      );
      expect(capturedRequest.headers['content-type'], 'application/json');
      expect(capturedRequest.body, '{"token":"fcm-token"}');
    });

    test('sends JSON DELETE requests', () async {
      late http.Request capturedRequest;
      final client = ApiClient(
        baseUrl: Uri.parse('http://127.0.0.1:3000'),
        httpClient: MockClient((request) async {
          capturedRequest = request;
          return http.Response('{"deleted":true}', 200);
        }),
      );

      final response = await client.deleteJson(
        '/v1/devices/token%2Fwith%2Fslash',
      );

      expect(response['deleted'], isTrue);
      expect(capturedRequest.method, 'DELETE');
      expect(
        capturedRequest.url.toString(),
        'http://127.0.0.1:3000/v1/devices/token%2Fwith%2Fslash',
      );
    });

    test('wraps network failures as ApiException', () async {
      final client = ApiClient(
        baseUrl: Uri.parse('http://127.0.0.1:3000'),
        httpClient: MockClient((_) async => throw Exception('offline')),
      );

      await expectLater(
        client.getJson('/v1/health'),
        throwsA(
          isA<ApiException>().having(
            (error) => error.kind,
            'kind',
            ApiExceptionKind.network,
          ),
        ),
      );
    });
  });
}
