import 'dart:async';
import 'dart:io';
import 'dart:typed_data';
import 'dart:ui' as ui;
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:on_this_day_mobile/features/quiz/presentation/images/quiz_image_preparer.dart';
import 'package:on_this_day_mobile/features/quiz/presentation/images/quiz_image_preparation_exception.dart';
import 'package:on_this_day_mobile/features/quiz/presentation/images/quiz_image_downloader.dart';
import 'package:on_this_day_mobile/features/quiz/presentation/images/quiz_image_decoder.dart';
import '../support/image_fakes.dart';

class StreamClient extends http.BaseClient {
  StreamClient(this.handler);
  final Future<http.StreamedResponse> Function(http.BaseRequest) handler;
  @override
  Future<http.StreamedResponse> send(http.BaseRequest request) =>
      handler(request);
}

class WaitingDownloader implements QuizImageDownloader {
  final pending = <Completer<Uint8List>>[];
  int active = 0, maximum = 0;
  @override
  Future<Uint8List> download(
    Uri url,
    QuizImageCancellation cancellation, {
    required int maxBytes,
    required void Function(int) reserveBytes,
  }) async {
    active++;
    if (active > maximum) maximum = active;
    final done = Completer<Uint8List>();
    pending.add(done);
    try {
      return await cancellation.wait(done.future);
    } finally {
      active--;
    }
  }
}

class DelayedDecoder implements QuizImageDecoder {
  final pending = <Completer<ui.Image>>[];
  @override
  Future<ui.Image> decode(
    Uint8List bytes,
    QuizImageCancellation cancellation, {
    required int maxEdge,
    required void Function(int) reserveDecodedBytes,
  }) {
    reserveDecodedBytes(40 * 20 * 4);
    final done = Completer<ui.Image>();
    pending.add(done);
    return done.future;
  }
}

Matcher failure(QuizImageFailure kind) =>
    isA<QuizImagePreparationException>().having((e) => e.kind, 'kind', kind);
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  test('optional downloaded canonical images meet decode bounds', () async {
    const directory = String.fromEnvironment('QUIZ_IMAGE_ASSET_DIR');
    if (directory.isEmpty) return;
    final files = Directory(directory)
        .listSync()
        .whereType<File>()
        .where(
          (f) =>
              f.path.split('/').last.startsWith('mq5-identify-') &&
              f.path.endsWith('.img') &&
              f.lengthSync() > 0,
        )
        .toList();
    expect(files, isNotEmpty);
    var totalDecoded = 0;
    for (final file in files) {
      final bytes = await file.readAsBytes();
      expect(bytes.length, lessThanOrEqualTo(8 * 1024 * 1024));
      final image = await FlutterQuizImageDecoder().decode(
        bytes,
        QuizImageCancellation(),
        maxEdge: 1024,
        reserveDecodedBytes: (n) => totalDecoded += n,
      );
      // Local diagnostic output, not part of application logging.
      // ignore: avoid_print
      print(
        '${file.uri.pathSegments.last}: ${bytes.length} bytes -> ${image.width}x${image.height}',
      );
      image.dispose();
    }
    expect(totalDecoded, lessThanOrEqualTo(32 * 1024 * 1024));
  });
  test('default budgets and invalid bounds', () {
    final limits = QuizImageLimits();
    expect(limits.perImage, const Duration(seconds: 15));
    expect(limits.batch, const Duration(seconds: 60));
    expect(limits.encodedImage, 8 * 1024 * 1024);
    expect(limits.encodedSession, 32 * 1024 * 1024);
    expect(limits.decodedSession, 32 * 1024 * 1024);
    expect(limits.maxEdge, 1024);
    expect(() => QuizImageLimits(maxEdge: 1025), throwsArgumentError);
    expect(() => QuizImageLimits(perImage: Duration.zero), throwsArgumentError);
  });
  test(
    'stream limits count chunks with no content length and cancel subscription',
    () async {
      var cancelled = false, retained = 0;
      final stream = StreamController<List<int>>(
        onCancel: () {
          cancelled = true;
        },
      );
      final client = StreamClient((request) async {
        expect(request, isA<http.AbortableRequest>());
        expect(request.followRedirects, isFalse);
        return http.StreamedResponse(stream.stream, 200);
      });
      final future = HttpQuizImageDownloader(client).download(
        Uri.parse('https://example.org/image'),
        QuizImageCancellation(),
        maxBytes: 4,
        reserveBytes: (n) => retained += n,
      );
      final check = expectLater(
        future,
        throwsA(failure(QuizImageFailure.encodedLimit)),
      );
      stream.add([1, 2, 3]);
      stream.add([4, 5]);
      await check;
      expect(retained, 3);
      expect(cancelled, isTrue);
      await stream.close();
    },
  );
  test(
    'declared oversized length and non-success status fail without buffering',
    () async {
      for (final status in [200, 404]) {
        final client = StreamClient(
          (_) async => http.StreamedResponse(
            const Stream.empty(),
            status,
            contentLength: 100,
          ),
        );
        await expectLater(
          HttpQuizImageDownloader(client).download(
            Uri.parse('https://example.org/i'),
            QuizImageCancellation(),
            maxBytes: 10,
            reserveBytes: (_) => fail('Must not retain bytes'),
          ),
          throwsA(isA<QuizImagePreparationException>()),
        );
      }
    },
  );
  test(
    'cancellation signals abort and ignores late headers from an uncooperative client',
    () async {
      final headers = Completer<http.StreamedResponse>();
      final cancellation = QuizImageCancellation();
      final stream = StreamController<List<int>>();
      final client = StreamClient((r) {
        expect((r as http.AbortableRequest).abortTrigger, cancellation.signal);
        return headers.future;
      });
      final future = HttpQuizImageDownloader(client).download(
        Uri.parse('https://example.org/i'),
        cancellation,
        maxBytes: 10,
        reserveBytes: (_) => fail('Late data retained'),
      );
      final check = expectLater(
        future,
        throwsA(failure(QuizImageFailure.cancelled)),
      );
      cancellation.cancel();
      await check;
      headers.complete(http.StreamedResponse(stream.stream, 200));
      await Future<void>.delayed(Duration.zero);
      await stream.close();
    },
  );
  test(
    'deduplication creates every mapping but downloads and decodes once',
    () async {
      final downloader = BytesDownloader(await testImageBytes());
      final resources = await QuizImagePreparer(
        downloader: downloader,
        decoder: FlutterQuizImageDecoder(),
      ).call(imageQuiz(unique: false)).result;
      expect(downloader.calls, 1);
      for (var i = 0; i < 5; i++) {
        expect(resources.images!.contains('q-$i'), isTrue);
      }
      final display = resources.images!.acquire('q-0')!;
      resources.release();
      resources.release();
      expect(display.width, 40);
      display.dispose();
      expect(resources.images!.contains('q-0'), isFalse);
    },
  );
  test(
    'encoded session and decoded session limits fail the whole batch',
    () async {
      final bytes = await testImageBytes();
      for (final limits in [
        QuizImageLimits(encodedSession: bytes.length * 2),
        QuizImageLimits(decodedSession: 3200),
      ]) {
        final result = QuizImagePreparer(
          downloader: BytesDownloader(bytes),
          decoder: FlutterQuizImageDecoder(),
          limits: limits,
        ).call(imageQuiz()).result;
        await expectLater(
          result,
          throwsA(isA<QuizImagePreparationException>()),
        );
      }
    },
  );
  test('invalid encoded image fails decoding before ready', () async {
    await expectLater(
      QuizImagePreparer(
        downloader: BytesDownloader(Uint8List.fromList([0, 1])),
        decoder: FlutterQuizImageDecoder(),
      ).call(imageQuiz()).result,
      throwsA(failure(QuizImageFailure.decoding)),
    );
  });
  test(
    'descriptor constrains decode before display without upscaling',
    () async {
      final bytes = await testImageBytes(width: 1200, height: 600);
      var reserved = 0;
      final image = await FlutterQuizImageDecoder().decode(
        bytes,
        QuizImageCancellation(),
        maxEdge: 1024,
        reserveDecodedBytes: (n) => reserved = n,
      );
      expect(image.width, 1024);
      expect(image.height, 512);
      expect(reserved, 1024 * 512 * 4);
      image.dispose();
    },
  );
  testWidgets('two workers maximum and per-image timeout stops the batch', (
    tester,
  ) async {
    final downloader = WaitingDownloader();
    final attempt = QuizImagePreparer(
      downloader: downloader,
      decoder: FlutterQuizImageDecoder(),
    ).call(imageQuiz());
    final check = expectLater(
      attempt.result,
      throwsA(failure(QuizImageFailure.timeout)),
    );
    await tester.pump();
    expect(downloader.maximum, 2);
    expect(downloader.pending.length, 2);
    await tester.pump(const Duration(seconds: 15));
    await check;
    await tester.pump();
    expect(downloader.active, 0);
  });
  testWidgets('batch deadline includes queued work', (tester) async {
    final downloader = WaitingDownloader();
    final attempt = QuizImagePreparer(
      downloader: downloader,
      decoder: FlutterQuizImageDecoder(),
      limits: QuizImageLimits(perImage: const Duration(seconds: 90)),
    ).call(imageQuiz());
    final check = expectLater(
      attempt.result,
      throwsA(failure(QuizImageFailure.timeout)),
    );
    await tester.pump(const Duration(seconds: 60));
    await check;
    await tester.pump();
    expect(downloader.active, 0);
  });
  testWidgets('late decoded handles are disposed after cancellation', (
    tester,
  ) async {
    final bytes = (await tester.runAsync(testImageBytes))!;
    final decoder = DelayedDecoder();
    final attempt = QuizImagePreparer(
      downloader: BytesDownloader(bytes),
      decoder: decoder,
    ).call(imageQuiz());
    final check = expectLater(
      attempt.result,
      throwsA(failure(QuizImageFailure.cancelled)),
    );
    await tester.pump();
    expect(decoder.pending.length, 2);
    attempt.cancel();
    attempt.cancel();
    await tester.pump();
    await check;
    for (final pending in decoder.pending) {
      final image = (await tester.runAsync(testImage))!;
      pending.complete(image);
      await tester.pump();
      expect(image.debugDisposed, isTrue);
    }
  });
}
