import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:crypto/crypto.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:on_this_day_mobile/core/images/encoded_image_cache.dart';
import 'package:on_this_day_mobile/core/images/flutter_image_decoder.dart';
import 'package:on_this_day_mobile/core/images/image_request_cancellation.dart';

import '../../features/quiz/support/image_fakes.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test(
    'cold fetch publishes validated bytes and warm hit avoids network',
    () async {
      final fixture = await _fixture();
      final calls = <int>[];
      final imageCache = fixture.cache();

      final first = await _load(
        imageCache,
        fixture.url('one'),
        fixture.bytes,
        calls,
      );
      first.dispose();
      final warm = await _load(
        imageCache,
        fixture.url('one'),
        fixture.bytes,
        calls,
      );
      warm.dispose();

      expect(calls, [1]);
      expect(await fixture.entryFiles(), hasLength(1));
    },
  );

  test('URL changes use distinct entries', () async {
    final fixture = await _fixture();
    final calls = <int>[];
    final imageCache = fixture.cache();

    (await _load(
      imageCache,
      fixture.url('one'),
      fixture.bytes,
      calls,
    )).dispose();
    (await _load(
      imageCache,
      fixture.url('two'),
      fixture.bytes,
      calls,
    )).dispose();

    expect(calls, [1, 2]);
    expect(await fixture.entryFiles(), hasLength(2));
  });

  test('corrupt cached bytes are deleted and refetched once', () async {
    final fixture = await _fixture();
    final calls = <int>[];
    final imageCache = fixture.cache();
    (await _load(
      imageCache,
      fixture.url('one'),
      fixture.bytes,
      calls,
    )).dispose();

    final entry = (await fixture.entryFiles()).single;
    const corrupt = <int>[0, 1, 2, 3];
    await entry.writeAsBytes(corrupt, flush: true);
    final indexFile = File('${fixture.directory.path}/index.json');
    final index =
        jsonDecode(await indexFile.readAsString()) as Map<String, dynamic>;
    final metadata =
        (index['entries'] as Map<String, dynamic>).values.single
            as Map<String, dynamic>;
    metadata['length'] = corrupt.length;
    metadata['checksum'] = sha256.convert(corrupt).toString();
    await indexFile.writeAsString(jsonEncode(index), flush: true);

    final refetched = await _load(
      fixture.cache(),
      fixture.url('one'),
      fixture.bytes,
      calls,
    );
    refetched.dispose();

    expect(calls, [1, 2]);
  });

  test('missing or corrupt index rebuilds checksums before warm use', () async {
    final fixture = await _fixture();
    final calls = <int>[];
    (await _load(
      fixture.cache(),
      fixture.url('one'),
      fixture.bytes,
      calls,
    )).dispose();
    await File('${fixture.directory.path}/index.json').writeAsString('{bad');

    final warm = await _load(
      fixture.cache(),
      fixture.url('one'),
      fixture.bytes,
      calls,
    );
    warm.dispose();

    expect(calls, [1]);
  });

  test(
    'orphan cleanup, LRU eviction, restart and OS cache clearing recover',
    () async {
      final fixture = await _fixture();
      final calls = <int>[];
      final imageCache = fixture.cache(
        maxBytes: fixture.bytes.length * 2 + 1,
        maxEntryBytes: fixture.bytes.length + 1,
      );
      (await _load(
        imageCache,
        fixture.url('one'),
        fixture.bytes,
        calls,
      )).dispose();
      await Future<void>.delayed(const Duration(milliseconds: 2));
      (await _load(
        imageCache,
        fixture.url('two'),
        fixture.bytes,
        calls,
      )).dispose();
      await Future<void>.delayed(const Duration(milliseconds: 2));
      (await _load(
        imageCache,
        fixture.url('one'),
        fixture.bytes,
        calls,
      )).dispose();
      await Future<void>.delayed(const Duration(milliseconds: 2));
      (await _load(
        imageCache,
        fixture.url('three'),
        fixture.bytes,
        calls,
      )).dispose();

      expect(await fixture.entryFiles(), hasLength(2));
      (await _load(
        fixture.cache(),
        fixture.url('two'),
        fixture.bytes,
        calls,
      )).dispose();
      expect(calls, [1, 2, 3, 4]);

      final orphan = File('${fixture.directory.path}/${'a' * 64}.bin');
      final temporary = File('${fixture.directory.path}/orphan.tmp');
      await orphan.writeAsBytes(fixture.bytes);
      await temporary.writeAsBytes(fixture.bytes);
      (await _load(
        fixture.cache(),
        fixture.url('one'),
        fixture.bytes,
        calls,
      )).dispose();
      expect(await orphan.exists(), isFalse);
      expect(await temporary.exists(), isFalse);

      await fixture.directory.delete(recursive: true);
      (await _load(
        fixture.cache(),
        fixture.url('one'),
        fixture.bytes,
        calls,
      )).dispose();
      expect(calls, [1, 2, 3, 4, 5]);
    },
  );

  test('same-key callers share work and cancellation is independent', () async {
    final fixture = await _fixture();
    final imageCache = fixture.cache();
    final response = Completer<Uint8List>();
    var calls = 0;
    final firstCancellation = ImageRequestCancellation();
    final secondCancellation = ImageRequestCancellation();
    final first = _load(
      imageCache,
      fixture.url('one'),
      fixture.bytes,
      <int>[],
      cancellation: firstCancellation,
      fetch: (shared) {
        calls++;
        return shared.wait(response.future);
      },
    );
    final second = _load(
      imageCache,
      fixture.url('one'),
      fixture.bytes,
      <int>[],
      cancellation: secondCancellation,
      fetch: (shared) {
        calls++;
        return shared.wait(response.future);
      },
    );

    firstCancellation.cancel();
    await expectLater(first, throwsA(isA<ImageRequestCancelledException>()));
    response.complete(fixture.bytes);
    (await second).dispose();

    expect(calls, 1);
  });

  test(
    'a new caller replaces a shared load after its last waiter cancels',
    () async {
      final fixture = await _fixture();
      final imageCache = fixture.cache();
      final firstCancellation = ImageRequestCancellation();
      final firstResponse = Completer<Uint8List>();
      final firstStarted = Completer<void>();
      var calls = 0;
      final first = _load(
        imageCache,
        fixture.url('one'),
        fixture.bytes,
        <int>[],
        cancellation: firstCancellation,
        fetch: (shared) {
          calls++;
          firstStarted.complete();
          return shared.wait(firstResponse.future);
        },
      );
      await firstStarted.future;
      firstCancellation.cancel();
      await expectLater(first, throwsA(isA<ImageRequestCancelledException>()));

      final second = await _load(
        imageCache,
        fixture.url('one'),
        fixture.bytes,
        <int>[],
        fetch: (_) {
          calls++;
          return Future.value(fixture.bytes);
        },
      );
      second.dispose();
      expect(calls, 2);
    },
  );
}

Future<ui.Image> _load(
  EncodedImageCache imageCache,
  Uri url,
  Uint8List bytes,
  List<int> calls, {
  ImageRequestCancellation? cancellation,
  FetchEncodedImage? fetch,
}) {
  final token = cancellation ?? ImageRequestCancellation();
  return imageCache.load(
    url,
    token,
    maxBytes: imageCache.maxEntryBytes,
    maxEdge: 1024,
    download:
        fetch ??
        (_) async {
          calls.add(calls.length + 1);
          return bytes;
        },
    decode: FlutterImageDecoder().decode,
    reserveEncodedBytes: (_) {},
    reserveDecodedBytes: (_) {},
  );
}

final class _Fixture {
  _Fixture(this.directory, this.bytes);

  final Directory directory;
  final Uint8List bytes;

  EncodedImageCache cache({int? maxBytes, int? maxEntryBytes}) =>
      EncodedImageCache(
        cacheDirectory: () async => directory,
        maxBytes: maxBytes ?? 64 * 1024 * 1024,
        maxEntryBytes: maxEntryBytes ?? 8 * 1024 * 1024,
      );

  Uri url(String value) => Uri.parse('https://images.example.org/$value.png');

  Future<List<File>> entryFiles() => directory
      .list()
      .where((entity) => entity is File && entity.path.endsWith('.bin'))
      .cast<File>()
      .toList();
}

Future<_Fixture> _fixture() async {
  final directory = await Directory.systemTemp.createTemp('image-cache-test-');
  final bytes = await testImageBytes();
  addTearDown(() => directory.delete(recursive: true));
  return _Fixture(directory, bytes);
}
