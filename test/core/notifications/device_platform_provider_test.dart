import 'package:flutter_test/flutter_test.dart';
import 'package:on_this_day_mobile/core/notifications/device_platform_provider.dart';

void main() {
  group('PlatformDevicePlatformProvider', () {
    test('maps iOS platform', () async {
      final provider = PlatformDevicePlatformProvider(operatingSystem: 'ios');

      expect(await provider.currentPlatform(), DevicePlatform.ios);
      expect(DevicePlatform.ios.toJsonValue(), 'ios');
    });

    test('maps Android platform', () async {
      final provider = PlatformDevicePlatformProvider(
        operatingSystem: 'android',
      );

      expect(await provider.currentPlatform(), DevicePlatform.android);
      expect(DevicePlatform.android.toJsonValue(), 'android');
    });

    test('rejects unsupported platforms', () async {
      const provider = PlatformDevicePlatformProvider(operatingSystem: 'macos');

      await expectLater(
        provider.currentPlatform(),
        throwsA(isA<UnsupportedDevicePlatformException>()),
      );
    });
  });
}
