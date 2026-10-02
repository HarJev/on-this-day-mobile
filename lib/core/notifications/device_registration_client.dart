import '../api/api_client.dart';
import '../api/api_exception.dart';
import 'device_platform_provider.dart';
import 'notification_service.dart';

class DeviceRegistrationRequest {
  const DeviceRegistrationRequest({
    required this.token,
    required this.platform,
    required this.timezone,
    required this.notificationPermissionStatus,
  })  : assert(token != ''),
        assert(timezone != '');

  final String token;
  final DevicePlatform platform;
  final String timezone;
  final NotificationPermissionStatus notificationPermissionStatus;

  Map<String, Object?> toJson() {
    return {
      'token': token,
      'platform': platform.toJsonValue(),
      'timezone': timezone,
      'notificationPermissionStatus':
          notificationPermissionStatus.toJsonValue(),
    };
  }
}

class DeviceRegistrationClient {
  static const maxTokenLength = 1024;

  const DeviceRegistrationClient({required ApiClient apiClient})
      : _apiClient = apiClient;

  final ApiClient _apiClient;

  Future<void> register(DeviceRegistrationRequest request) async {
    _validateToken(request.token);
    final json = await _apiClient.postJson(
      '/v1/devices',
      body: request.toJson(),
    );
    if (json['registered'] != true) {
      throw ApiException.invalidJson(
        cause: FormatException(
          'Expected device registration response to include registered=true.',
          json,
        ),
      );
    }
  }

  Future<void> deleteToken(String token) async {
    _validateToken(token);
    final encodedToken = Uri.encodeComponent(token);
    final json = await _apiClient.deleteJson('/v1/devices/$encodedToken');
    if (json['deleted'] != true) {
      throw ApiException.invalidJson(
        cause: FormatException(
          'Expected device deletion response to include deleted=true.',
          json,
        ),
      );
    }
  }

  static void _validateToken(String token) {
    if (token.isEmpty || token.length > maxTokenLength) {
      throw const ApiException.invalidRequest('Device token is invalid.');
    }
  }
}

extension NotificationPermissionStatusJson on NotificationPermissionStatus {
  String toJsonValue() {
    return switch (this) {
      NotificationPermissionStatus.authorized => 'authorized',
      // The backend contract has no permanent-denial value; both mean denied.
      NotificationPermissionStatus.denied ||
      NotificationPermissionStatus.permanentlyDenied =>
        'denied',
      NotificationPermissionStatus.notDetermined => 'not_determined',
      NotificationPermissionStatus.provisional => 'provisional',
    };
  }
}
