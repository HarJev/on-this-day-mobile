import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:on_this_day_mobile/core/notifications/notification_prompt_store.dart';

void main() {
  late Directory directory;
  late FileNotificationPromptStore store;

  setUp(() async {
    directory = await Directory.systemTemp.createTemp('prompt-store-');
    store = FileNotificationPromptStore(
      directory: () async => Directory('${directory.path}/support'),
    );
  });

  tearDown(() async {
    await directory.delete(recursive: true);
  });

  File file() => File('${directory.path}/support/notification_prompt.json');

  test('returns null before any decision', () async {
    expect(await store.read(), isNull);
  });

  test('persists and reads back each decision across instances', () async {
    for (final decision in NotificationPromptDecision.values) {
      await store.write(decision);
      final reopened = FileNotificationPromptStore(
        directory: () async => Directory('${directory.path}/support'),
      );
      expect(await reopened.read(), decision);
    }
    expect(File('${file().path}.tmp').existsSync(), isFalse);
  });

  test('treats a corrupt file as undecided', () async {
    await file().parent.create(recursive: true);
    await file().writeAsString('{not json');

    expect(await store.read(), isNull);
  });

  test('treats an unknown decision value as undecided', () async {
    await file().parent.create(recursive: true);
    await file().writeAsString('{"decision":"maybe"}');

    expect(await store.read(), isNull);
  });
}
