import 'dart:io';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:integration_test/integration_test.dart';
import 'package:on_this_day_mobile/core/api/api_client.dart';
import 'package:on_this_day_mobile/core/images/encoded_image_cache.dart';
import 'package:on_this_day_mobile/core/images/flutter_image_decoder.dart';
import 'package:on_this_day_mobile/core/images/image_downloader.dart';
import 'package:on_this_day_mobile/core/images/image_request_cancellation.dart';
import 'package:on_this_day_mobile/features/quiz/data/backend_quiz_repository.dart';
import 'package:on_this_day_mobile/features/quiz/domain/quiz_question.dart';
import 'package:path_provider/path_provider.dart';

/// Explicitly opt in: requires local SAM and imported quiz content.
void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();
  const enabled = bool.fromEnvironment('LIVE_IMAGE_CACHE_TEST');
  const baseUrl = String.fromEnvironment('ON_THIS_DAY_API_BASE_URL');

  testWidgets(
    'real Quick Play image is fetched once then served warm from cache',
    (tester) async {
      final client = http.Client();
      final temporary = await getTemporaryDirectory();
      final directory = Directory(
        '${temporary.path}/on-this-day-image-cache-live-${DateTime.now().microsecondsSinceEpoch}',
      );
      final cache = EncodedImageCache(cacheDirectory: () async => directory);
      final downloader = _CountingDownloader(HttpImageDownloader(client));
      addTearDown(() async {
        client.close();
        if (await directory.exists()) await directory.delete(recursive: true);
      });

      final definition = await BackendQuizRepository(
        apiClient: ApiClient(baseUrl: Uri.parse(baseUrl), httpClient: client),
      ).createQuickPlay(questionCount: 20);
      final question = definition.questions
          .whereType<ImageIdentificationQuestion>()
          .first;

      final cold = await _load(cache, downloader, question.image.url);
      cold.dispose();
      final warm = await _load(cache, downloader, question.image.url);
      warm.dispose();

      expect(downloader.calls, 1);
      expect(
        await directory
            .list()
            .where((entry) => entry is File && entry.path.endsWith('.bin'))
            .length,
        1,
      );
    },
    skip: !enabled || baseUrl.isEmpty,
    timeout: const Timeout(Duration(minutes: 2)),
  );
}

Future<dynamic> _load(
  EncodedImageCache cache,
  ImageByteDownloader downloader,
  Uri url,
) {
  final cancellation = ImageRequestCancellation();
  return cache.load(
    url,
    cancellation,
    maxBytes: 8 * 1024 * 1024,
    maxEdge: 1024,
    download: (shared) => downloader.download(
      url,
      shared,
      maxBytes: 8 * 1024 * 1024,
      reserveBytes: (_) {},
      deadline: DateTime.now().add(const Duration(seconds: 15)),
    ),
    decode: FlutterImageDecoder().decode,
    reserveEncodedBytes: (_) {},
    reserveDecodedBytes: (_) {},
  );
}

final class _CountingDownloader implements ImageByteDownloader {
  _CountingDownloader(this._delegate);

  final ImageByteDownloader _delegate;
  var calls = 0;

  @override
  Future<Uint8List> download(
    Uri url,
    ImageRequestCancellation cancellation, {
    required int maxBytes,
    required void Function(int) reserveBytes,
    DateTime? deadline,
  }) {
    calls++;
    return _delegate.download(
      url,
      cancellation,
      maxBytes: maxBytes,
      reserveBytes: reserveBytes,
      deadline: deadline,
    );
  }
}
