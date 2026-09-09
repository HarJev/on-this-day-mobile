import 'package:flutter_test/flutter_test.dart';
import 'package:on_this_day_mobile/core/config/app_config.dart';

void main() {
  test('uses iOS simulator local API fallback by default', () {
    final config = AppConfig.fromEnvironment();

    expect(config.apiBaseUrl, Uri.parse('http://127.0.0.1:3000'));
  });
}
