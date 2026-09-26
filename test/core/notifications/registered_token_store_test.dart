import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:on_this_day_mobile/core/notifications/registered_token_store.dart';

void main() {
  late Directory directory;
  late FileRegisteredTokenStore store;

  setUp(() async {
    directory = await Directory.systemTemp.createTemp('token-store-');
    store = FileRegisteredTokenStore(
      directory: () async => Directory('${directory.path}/support'),
    );
  });

  tearDown(() async {
    await directory.delete(recursive: true);
  });

  File file() => File('${directory.path}/support/registered_device_token.json');

  Future<List<FileSystemEntity>> temporaryFiles() => file().parent
      .list()
      .where((entry) => entry.path.endsWith('.tmp'))
      .toList();

  test('returns null when nothing is registered', () async {
    expect(await store.read(), isNull);
  });

  test('persists a token atomically across instances', () async {
    await store.write('confirmed-token');

    final reopened = FileRegisteredTokenStore(
      directory: () async => Directory('${directory.path}/support'),
    );
    expect(await reopened.read(), 'confirmed-token');
    expect(await temporaryFiles(), isEmpty);
  });

  test('serializes concurrent writes and clears', () async {
    await Future.wait([
      store.write('first'),
      store.write('second'),
      store.clear(),
      store.write('third'),
    ]);

    expect(await store.read(), 'third');
    expect(await temporaryFiles(), isEmpty);
  });

  test('clear removes the token and tolerates a missing file', () async {
    await store.clear();
    await store.write('token');
    await store.clear();

    expect(await store.read(), isNull);
    expect(file().existsSync(), isFalse);
  });

  test('rejects an empty token', () {
    expect(() => store.write(''), throwsArgumentError);
  });

  test('reports corrupt data instead of guessing', () async {
    await file().parent.create(recursive: true);
    await file().writeAsString('{"token":42}');
    await expectLater(store.read(), throwsFormatException);

    await file().writeAsString('not json');
    await expectLater(store.read(), throwsFormatException);
  });
}
