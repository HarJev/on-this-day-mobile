import 'dart:convert';

import 'package:crypto/crypto.dart';
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
      expect(
        capturedRequest.headers['x-amz-content-sha256'],
        sha256.convert(utf8.encode('{"token":"fcm-token"}')).toString(),
      );
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
      expect(capturedRequest.bodyBytes, isEmpty);
      expect(
        capturedRequest.headers['x-amz-content-sha256'],
        'e3b0c44298fc1c149afbf4c8996fb92427ae41e4649b934ca495991b7852b855',
      );
      expect(
        capturedRequest.url.toString(),
        'http://127.0.0.1:3000/v1/devices/token%2Fwith%2Fslash',
      );
    });

    test('hashes the exact UTF-8 bytes sent for non-ASCII JSON', () async {
      late http.Request capturedRequest;
      final client = ApiClient(
        baseUrl: Uri.parse('https://d123example.cloudfront.net'),
        httpClient: MockClient((request) async {
          capturedRequest = request;
          return http.Response('{}', 200);
        }),
      );

      await client.postJson('/v1/quizzes/quick-play', body: {'name': 'José'});

      final expectedBytes = utf8.encode('{"name":"José"}');
      expect(capturedRequest.bodyBytes, expectedBytes);
      expect(
        capturedRequest.headers['x-amz-content-sha256'],
        sha256.convert(expectedBytes).toString(),
      );
    });

    test('GET does not include a content hash header', () async {
      late http.Request capturedRequest;
      final client = ApiClient(
        baseUrl: Uri.parse('https://d123example.cloudfront.net'),
        httpClient: MockClient((request) async {
          capturedRequest = request;
          return http.Response('{}', 200);
        }),
      );

      await client.getJson('/v1/quizzes/catalog');

      expect(capturedRequest.headers, isNot(contains('x-amz-content-sha256')));
    });

    test('rejects bodies over 16 KB before sending', () async {
      var sent = false;
      final client = ApiClient(
        baseUrl: Uri.parse('https://d123example.cloudfront.net'),
        httpClient: MockClient((_) async {
          sent = true;
          return http.Response('{}', 200);
        }),
      );

      await expectLater(
        client.postJson(
          '/v1/quizzes/quick-play',
          body: {'value': 'x' * ApiClient.maxRequestBodyBytes},
        ),
        throwsA(
          isA<ApiException>().having(
            (error) => error.kind,
            'kind',
            ApiExceptionKind.invalidRequest,
          ),
        ),
      );
      expect(sent, isFalse);
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
