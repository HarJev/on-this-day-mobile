import 'package:url_launcher/url_launcher.dart';

abstract interface class SourceLauncher {
  Future<bool> open(Uri url);
}

class PlatformSourceLauncher implements SourceLauncher {
  const PlatformSourceLauncher();

  @override
  Future<bool> open(Uri url) {
    return launchUrl(url, mode: LaunchMode.externalApplication);
  }
}
