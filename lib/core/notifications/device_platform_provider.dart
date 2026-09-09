import 'dart:io' show Platform;

enum DevicePlatform { android, ios }

class UnsupportedDevicePlatformException implements Exception {
  const UnsupportedDevicePlatformException(this.operatingSystem);

  final String operatingSystem;

  @override
  String toString() {
    return 'UnsupportedDevicePlatformException($operatingSystem)';
  }
}

abstract interface class DevicePlatformProvider {
  Future<DevicePlatform> currentPlatform();
}

class PlatformDevicePlatformProvider implements DevicePlatformProvider {
  const PlatformDevicePlatformProvider({String? operatingSystem})
    : _operatingSystem = operatingSystem;

  final String? _operatingSystem;

  @override
  Future<DevicePlatform> currentPlatform() async {
    final operatingSystem = _operatingSystem ?? Platform.operatingSystem;
    return switch (operatingSystem) {
      'android' => DevicePlatform.android,
      'ios' => DevicePlatform.ios,
      _ => throw UnsupportedDevicePlatformException(operatingSystem),
    };
  }
}

extension DevicePlatformJson on DevicePlatform {
  String toJsonValue() {
    return switch (this) {
      DevicePlatform.android => 'android',
      DevicePlatform.ios => 'ios',
    };
  }
}
