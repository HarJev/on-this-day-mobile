import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:on_this_day_mobile/core/api/api_client.dart';
import 'package:on_this_day_mobile/core/api/api_exception.dart';
import 'package:on_this_day_mobile/core/notifications/device_platform_provider.dart';
import 'package:on_this_day_mobile/core/notifications/device_registration_client.dart';
import 'package:on_this_day_mobile/core/notifications/notification_service.dart';

void main() {
  group('DeviceRegistrationRequest', () {
    test('serializes backend payload', () {
      const request = DeviceRegistrationRequest(
        token: 'fcm-token',
        platform: DevicePlatform.ios,
        timezone: 'America/Jamaica',
        notificationPermissionStatus:
            NotificationPermissionStatus.notDetermined,
      );

      expect(request.toJson(), {
        'token': 'fcm-token',
        'platform': 'ios',
        'timezone': 'America/Jamaica',
        'notificationPermissionStatus': 'not_determined',
      });
    });
  });

  group('DeviceRegistrationClient', () {
    test('registers a device token', () async {
      late http.Request capturedRequest;
      final client = DeviceRegistrationClient(
        apiClient: ApiClient(
          baseUrl: Uri.parse('http://127.0.0.1:3000'),
          httpClient: MockClient((request) async {
            capturedRequest = request;
            return http.Response('{"registered":true}', 200);
          }),
        ),
      );

      await client.register(
        const DeviceRegistrationRequest(
          token: 'fcm-token',
          platform: DevicePlatform.android,
          timezone: 'America/Jamaica',
          notificationPermissionStatus: NotificationPermissionStatus.authorized,
        ),
      );

      expect(capturedRequest.method, 'POST');
      expect(capturedRequest.url.path, '/v1/devices');
      expect(jsonDecode(capturedRequest.body), {
        'token': 'fcm-token',
        'platform': 'android',
        'timezone': 'America/Jamaica',
        'notificationPermissionStatus': 'authorized',
      });
    });

    test('deletes a URL-encoded token', () async {
      late Uri capturedUri;
      final client = DeviceRegistrationClient(
        apiClient: ApiClient(
          baseUrl: Uri.parse('http://127.0.0.1:3000'),
          httpClient: MockClient((request) async {
            capturedUri = request.url;
            return http.Response('{"deleted":true}', 200);
          }),
        ),
      );

      await client.deleteToken('token/with+symbols=');

      expect(
        capturedUri.toString(),
        'http://127.0.0.1:3000/v1/devices/token%2Fwith%2Bsymbols%3D',
      );
    });

    test('treats unexpected response JSON as invalid API response', () async {
      final client = DeviceRegistrationClient(
        apiClient: ApiClient(
          baseUrl: Uri.parse('http://127.0.0.1:3000'),
          httpClient: MockClient(
            (_) async => http.Response('{"ok":true}', 200),
          ),
        ),
      );

      await expectLater(
        client.register(
          const DeviceRegistrationRequest(
            token: 'fcm-token',
            platform: DevicePlatform.ios,
            timezone: 'America/Jamaica',
            notificationPermissionStatus:
                NotificationPermissionStatus.authorized,
          ),
        ),
        throwsA(
          isA<ApiException>().having(
            (error) => error.kind,
            'kind',
            ApiExceptionKind.invalidJson,
          ),
        ),
      );
    });
  });
}
