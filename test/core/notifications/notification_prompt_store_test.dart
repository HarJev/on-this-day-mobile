import 'dart:convert';
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

  Future<void> writeRaw(String content) async {
    await file().parent.create(recursive: true);
    await file().writeAsString(content);
  }

  Future<List<String>> temporaryFiles() => file().parent
      .list()
      .where((entry) => entry.path.endsWith('.tmp'))
      .map((entry) => entry.path)
      .toList();

  test('returns null before any answer', () async {
    expect(await store.read(), isNull);
  });

  test('round-trips records across instances without leftovers', () async {
    final records = [
      NotificationPromptRecord(
        declineCount: 1,
        declinedAt: DateTime.utc(2026, 9, 1, 12),
      ),
      NotificationPromptRecord(
        declineCount: 2,
        declinedAt: DateTime.utc(2026, 10, 2, 8),
      ),
      NotificationPromptRecord(
        requested: true,
        declineCount: 1,
        declinedAt: DateTime.utc(2026, 9, 1),
      ),
    ];
    for (final record in records) {
      await store.write(record);
      final reopened = FileNotificationPromptStore(
        directory: () async => Directory('${directory.path}/support'),
      );
      expect(await reopened.read(), record);
    }
    expect(await temporaryFiles(), isEmpty);
  });

  test('serializes concurrent writes and keeps the last one', () async {
    await Future.wait([
      store.write(
        NotificationPromptRecord(
          declineCount: 1,
          declinedAt: DateTime.utc(2026, 9, 1),
        ),
      ),
      store.write(const NotificationPromptRecord(requested: true)),
    ]);

    expect(await store.read(), const NotificationPromptRecord(requested: true));
    expect(await temporaryFiles(), isEmpty);
  });

  group('legacy first-release format', () {
    test('a legacy decline becomes one decline at updatedAt', () async {
      await writeRaw(
        jsonEncode({
          'decision': 'declined',
          'updatedAt': '2026-09-26T19:25:00.000Z',
        }),
      );

      expect(
        await store.read(),
        NotificationPromptRecord(
          declineCount: 1,
          declinedAt: DateTime.utc(2026, 9, 26, 19, 25),
        ),
      );
    });

    test('a legacy request stays a completed request', () async {
      await writeRaw(
        jsonEncode({
          'decision': 'requested',
          'updatedAt': '2026-09-26T19:25:00.000Z',
        }),
      );

      expect(
        await store.read(),
        const NotificationPromptRecord(requested: true),
      );
    });

    test('a legacy decline without a usable time fails closed', () async {
      await writeRaw(jsonEncode({'decision': 'declined'}));
      await expectLater(store.read(), throwsFormatException);

      await writeRaw(
        jsonEncode({'decision': 'declined', 'updatedAt': 'yesterday'}),
      );
      await expectLater(store.read(), throwsFormatException);
    });
  });

  group('corrupt or unknown data fails closed', () {
    for (final (label, content) in [
      ('not JSON', '{not json'),
      ('not an object', '[1, 2]'),
      ('unknown legacy decision', '{"decision":"maybe"}'),
      ('unknown version', '{"version":3,"requested":false,"declineCount":0}'),
      (
        'wrong field type',
        '{"version":2,"requested":"yes","declineCount":0,"declinedAt":null}',
      ),
      (
        'negative count',
        '{"version":2,"requested":false,"declineCount":-1,"declinedAt":null}',
      ),
      (
        'decline without time',
        '{"version":2,"requested":false,"declineCount":1,"declinedAt":null}',
      ),
    ]) {
      test(label, () async {
        await writeRaw(content);

        await expectLater(store.read(), throwsFormatException);
      });
    }
  });
}
