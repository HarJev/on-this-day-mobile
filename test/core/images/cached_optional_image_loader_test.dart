import 'dart:io';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:on_this_day_mobile/core/images/cached_optional_image_loader.dart';
import 'package:on_this_day_mobile/core/images/encoded_image_cache.dart';
import 'package:on_this_day_mobile/core/images/image_downloader.dart';
import 'package:on_this_day_mobile/core/images/image_request_cancellation.dart';

import '../../features/quiz/support/image_fakes.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test(
    'optional image loading supplies its bounded request deadline',
    () async {
      final directory = await Directory.systemTemp.createTemp(
        'optional-image-',
      );
      addTearDown(() => directory.delete(recursive: true));
      final downloader = _RecordingDownloader(await testImageBytes());
      final loader = CachedOptionalImageLoader(
        cache: EncodedImageCache(cacheDirectory: () async => directory),
        downloader: downloader,
      );
      final before = DateTime.now();

      final image = await loader.load(
        Uri.parse('https://images.example.org/archive.jpg'),
        ImageRequestCancellation(),
      );
      image.dispose();

      expect(downloader.deadline, isNotNull);
      expect(
        downloader.deadline!.difference(before).inMilliseconds,
        inInclusiveRange(14000, 16000),
      );
    },
  );

  test('optional image loading rejects a non-positive timeout', () {
    expect(
      () => CachedOptionalImageLoader(
        cache: EncodedImageCache(
          cacheDirectory: () async => Directory.systemTemp,
        ),
        downloader: _RecordingDownloader(Uint8List(0)),
        perImageTimeout: Duration.zero,
      ),
      throwsArgumentError,
    );
  });
}

final class _RecordingDownloader implements ImageByteDownloader {
  _RecordingDownloader(this.bytes);

  final Uint8List bytes;
  DateTime? deadline;

  @override
  Future<Uint8List> download(
    Uri url,
    ImageRequestCancellation cancellation, {
    required int maxBytes,
    required void Function(int) reserveBytes,
    DateTime? deadline,
  }) async {
    this.deadline = deadline;
    reserveBytes(bytes.length);
    return bytes;
  }
}
