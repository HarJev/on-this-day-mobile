import 'package:flutter/foundation.dart';

class AppConfig {
  const AppConfig({required this.apiBaseUrl});

  static const localApiBaseUrl = 'http://127.0.0.1:3000';
  static const releaseApiBaseUrlPlaceholder =
      'https://REPLACE_WITH_API_BASE_URL.cloudfront.net';

  factory AppConfig.fromEnvironment() {
    const configuredBaseUrl = String.fromEnvironment(
      'ON_THIS_DAY_API_BASE_URL',
      defaultValue: '',
    );

    return AppConfig.fromBaseUrl(configuredBaseUrl, isRelease: kReleaseMode);
  }

  factory AppConfig.fromBaseUrl(String value, {required bool isRelease}) {
    final selected = value.isEmpty
        ? (isRelease ? releaseApiBaseUrlPlaceholder : localApiBaseUrl)
        : value;
    final uri = Uri.tryParse(selected);
    if (uri == null || !uri.hasAuthority || uri.host.isEmpty) {
      throw StateError('Set ON_THIS_DAY_API_BASE_URL to a valid API URL.');
    }
    if (isRelease &&
        (selected == releaseApiBaseUrlPlaceholder ||
            uri.scheme != 'https' ||
            uri.userInfo.isNotEmpty ||
            uri.hasQuery ||
            uri.hasFragment ||
            const {
              'localhost',
              '127.0.0.1',
              '10.0.2.2',
              '::1',
            }.contains(uri.host.toLowerCase()))) {
      throw StateError(
        'Set ON_THIS_DAY_API_BASE_URL to the deployed CloudFront HTTPS API URL '
        'for release.',
      );
    }
    return AppConfig(apiBaseUrl: uri);
  }

  final Uri apiBaseUrl;
}
