import 'package:flutter_timezone/flutter_timezone.dart';

abstract interface class TimezoneProvider {
  Future<String> currentTimezone();
}

class PlatformTimezoneProvider implements TimezoneProvider {
  const PlatformTimezoneProvider();

  @override
  Future<String> currentTimezone() async {
    final timezone = await FlutterTimezone.getLocalTimezone();
    return timezone.identifier;
  }
}
