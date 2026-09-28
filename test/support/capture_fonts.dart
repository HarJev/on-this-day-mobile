import 'dart:io';

import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

/// Loads the bundled app faces and Material icons so opt-in screenshot
/// captures render real glyphs instead of the test font.
Future<void> loadCaptureFonts(WidgetTester tester) async {
  final flutterRoot = Platform.environment['FLUTTER_ROOT'];
  final families = <String, List<String>>{
    'SourceSerif4': [
      for (final weight in [400, 500, 600])
        'assets/fonts/SourceSerif4-$weight.ttf',
    ],
    'PublicSans': [
      for (final weight in [400, 500, 600])
        'assets/fonts/PublicSans-$weight.ttf',
    ],
    'MaterialIcons': [
      '$flutterRoot/bin/cache/artifacts/material_fonts/MaterialIcons-Regular.otf',
    ],
  };
  for (final MapEntry(key: family, value: paths) in families.entries) {
    final loader = FontLoader(family);
    for (final path in paths) {
      final bytes = await tester.runAsync(() => File(path).readAsBytes());
      loader.addFont(Future.value(ByteData.sublistView(bytes!)));
    }
    await loader.load();
  }
}
