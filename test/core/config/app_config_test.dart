import 'package:flutter_test/flutter_test.dart';
import 'package:on_this_day_mobile/core/config/app_config.dart';

void main() {
  test('uses the local API only in debug builds by default', () {
    final config = AppConfig.fromEnvironment();

    expect(config.apiBaseUrl, Uri.parse(AppConfig.localApiBaseUrl));
  });

  test('release has no local fallback when the define is absent', () {
    expect(
      () => AppConfig.fromBaseUrl('', isRelease: true),
      throwsStateError,
    );
    expect(
      AppConfig.fromBaseUrl('', isRelease: false).apiBaseUrl,
      Uri.parse(AppConfig.localApiBaseUrl),
    );
  });

  test('accepts the deployed CloudFront HTTPS URL in release', () {
    final config = AppConfig.fromBaseUrl(
      'https://d123example.cloudfront.net',
      isRelease: true,
    );

    expect(config.apiBaseUrl, Uri.parse('https://d123example.cloudfront.net'));
  });

  test('release rejects the placeholder and local or insecure URLs', () {
    for (final url in [
      AppConfig.releaseApiBaseUrlPlaceholder,
      AppConfig.localApiBaseUrl,
      'http://d123example.cloudfront.net',
      'https://localhost:3000',
      'https://10.0.2.2:3000',
      'https://127.0.0.1:3000',
      'https://[::1]:3000',
    ]) {
      expect(
        () => AppConfig.fromBaseUrl(url, isRelease: true),
        throwsStateError,
        reason: url,
      );
    }
  });

  test('release rejects malformed URLs and URL credentials', () {
    for (final url in [
      'not-a-url',
      'https://user:secret@d123example.cloudfront.net',
      'https://d123example.cloudfront.net?token=secret',
    ]) {
      expect(
        () => AppConfig.fromBaseUrl(url, isRelease: true),
        throwsStateError,
        reason: url,
      );
    }
  });

  test('debug still accepts local SAM URLs', () {
    final config = AppConfig.fromBaseUrl(
      'http://10.0.2.2:3001',
      isRelease: false,
    );

    expect(config.apiBaseUrl, Uri.parse('http://10.0.2.2:3001'));
  });
}
