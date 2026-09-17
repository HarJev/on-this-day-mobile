import 'dart:async';
import 'dart:developer' as developer;
import 'dart:io' show HttpDate, HttpException;
import 'dart:typed_data';
import 'package:http/http.dart' as http;
import 'quiz_image_preparation_exception.dart';

abstract interface class QuizImageDownloader {
  Future<Uint8List> download(
    Uri url,
    QuizImageCancellation cancellation, {
    required int maxBytes,
    required void Function(int) reserveBytes,
    DateTime? deadline,
  });
}

final class HttpQuizImageDownloader implements QuizImageDownloader {
  HttpQuizImageDownloader(
    this.client, {
    QuizImageRetryPolicy? retryPolicy,
    DateTime Function()? now,
    void Function(String message)? diagnostic,
  }) : _retryPolicy = retryPolicy ?? QuizImageRetryPolicy(),
       _now = now ?? DateTime.now,
       _diagnostic = diagnostic ?? _defaultDiagnostic {
    _cooldowns = _HostCooldownCoordinator(_now);
  }

  final http.Client client;
  final QuizImageRetryPolicy _retryPolicy;
  final DateTime Function() _now;
  final void Function(String message) _diagnostic;
  late final _HostCooldownCoordinator _cooldowns;

  static const _userAgent =
      'OnThisDayMobile/1.0 '
      '(+https://github.com/HarJev/on-this-day-mobile/issues)';

  @override
  Future<Uint8List> download(
    Uri url,
    QuizImageCancellation cancellation, {
    required int maxBytes,
    required void Function(int) reserveBytes,
    DateTime? deadline,
  }) async {
    cancellation.check();
    if (url.scheme != 'https') {
      throw const QuizImagePreparationException(QuizImageFailure.http);
    }

    final host = url.host.toLowerCase();
    for (var attempt = 0; attempt <= _retryPolicy.max429Retries; attempt++) {
      final permit = await _cooldowns.acquire(
        host,
        cancellation,
        deadline: deadline,
      );
      try {
        final response = await _send(url, cancellation);
        if (response.statusCode == 429) {
          await response.stream.listen((_) {}).cancel();
          if (attempt == _retryPolicy.max429Retries) {
            _diagnostic(
              'image_download host=$host status=429 failure=http retry=exhausted',
            );
            throw _httpFailure(url, response);
          }
          final retryAfter = _retryAfter(response.headers['retry-after']);
          final delay = retryAfter ?? _retryPolicy.backoffFor(attempt);
          _diagnostic(
            'image_download host=$host status=429 retry=${retryAfter == null ? 'backoff' : 'retry_after'} '
            'delayMs=${delay.inMilliseconds} attempt=${attempt + 1}',
          );
          _ensureDelayFitsDeadline(delay, cancellation, deadline);
          _cooldowns.extend(host, delay);
          continue;
        }
        return await _readResponse(
          url,
          response,
          cancellation,
          maxBytes: maxBytes,
          reserveBytes: reserveBytes,
        );
      } finally {
        permit.release();
      }
    }
    throw StateError('Unreachable retry state');
  }

  Future<http.StreamedResponse> _send(
    Uri url,
    QuizImageCancellation cancellation,
  ) {
    final request =
        http.AbortableRequest('GET', url, abortTrigger: cancellation.signal)
          ..headers['accept'] = 'image/*'
          ..headers['user-agent'] = _userAgent
          ..followRedirects = false;
    return cancellation.wait(
      client.send(request).then((response) {
        if (cancellation.isCancelled) {
          unawaited(response.stream.listen((_) {}).cancel());
          cancellation.check();
        }
        return response;
      }),
    );
  }

  Future<Uint8List> _readResponse(
    Uri url,
    http.StreamedResponse response,
    QuizImageCancellation cancellation, {
    required int maxBytes,
    required void Function(int) reserveBytes,
  }) async {
    if (response.statusCode != 200 ||
        (response.contentLength ?? 0) > maxBytes) {
      await response.stream.listen((_) {}).cancel();
      throw _httpFailure(url, response, maxBytes: maxBytes);
    }
    final bytes = BytesBuilder(copy: false);
    StreamSubscription<List<int>>? subscription;
    final done = Completer<void>();
    try {
      // Consume a late response even if an injected client ignores abort.
      subscription = response.stream.listen(
        (chunk) {
          if (done.isCompleted || cancellation.isCancelled) return;
          try {
            if (bytes.length + chunk.length > maxBytes) {
              throw const QuizImagePreparationException(
                QuizImageFailure.encodedLimit,
              );
            }
            reserveBytes(chunk.length);
            bytes.add(chunk);
          } catch (error, stack) {
            done.completeError(error, stack);
          }
        },
        onError: (Object error, StackTrace stack) {
          if (!done.isCompleted) done.completeError(error, stack);
        },
        onDone: () {
          if (!done.isCompleted) done.complete();
        },
      );
      await cancellation.wait(done.future);
      cancellation.check();
      return bytes.takeBytes();
    } finally {
      // Subscription cancellation does not promise forced termination of a socket.
      if (subscription != null) unawaited(subscription.cancel());
      bytes.clear();
    }
  }

  QuizImagePreparationException _httpFailure(
    Uri url,
    http.StreamedResponse response, {
    int? maxBytes,
  }) => QuizImagePreparationException(
    response.statusCode != 200
        ? QuizImageFailure.http
        : QuizImageFailure.encodedLimit,
  );

  Duration? _retryAfter(String? value) {
    if (value == null) return null;
    final trimmed = value.trim();
    final seconds = int.tryParse(trimmed);
    if (seconds != null && seconds >= 0) {
      return Duration(seconds: seconds);
    }
    try {
      final delay = HttpDate.parse(trimmed).toUtc().difference(_now().toUtc());
      return delay.isNegative ? Duration.zero : delay;
    } on FormatException {
      return null;
    } on HttpException {
      return null;
    }
  }

  void _ensureDelayFitsDeadline(
    Duration delay,
    QuizImageCancellation cancellation,
    DateTime? deadline,
  ) {
    cancellation.check();
    if (deadline == null) return;
    final remaining = deadline.difference(_now());
    if (remaining <= Duration.zero || delay >= remaining) {
      _diagnostic(
        'image_download failure=timeout retry=skipped delayMs=${delay.inMilliseconds} '
        'remainingMs=${remaining.inMilliseconds}',
      );
      throw const QuizImagePreparationException(QuizImageFailure.timeout);
    }
  }

  static void _defaultDiagnostic(String message) {
    developer.log(message, name: 'on_this_day.quiz_images');
  }
}

final class QuizImageRetryPolicy {
  QuizImageRetryPolicy({
    this.max429Retries = 2,
    this.initialBackoff = const Duration(milliseconds: 500),
    this.maxBackoff = const Duration(seconds: 2),
  }) {
    if (max429Retries < 0 ||
        initialBackoff.isNegative ||
        maxBackoff.isNegative) {
      throw ArgumentError('Retry policy values must be non-negative');
    }
  }

  final int max429Retries;
  final Duration initialBackoff;
  final Duration maxBackoff;

  Duration backoffFor(int retryAttempt) {
    final multiplier = 1 << retryAttempt;
    final delay = initialBackoff * multiplier;
    return delay > maxBackoff ? maxBackoff : delay;
  }
}

final class _HostCooldownCoordinator {
  _HostCooldownCoordinator(this._now);

  final DateTime Function() _now;
  final _hosts = <String, _HostCooldown>{};

  void extend(String host, Duration delay) {
    final cooldown = _hosts.putIfAbsent(host, _HostCooldown.new);
    cooldown.requiresPermit = true;
    cooldown.generation++;
    final candidate = _now().add(delay);
    if (cooldown.until == null || candidate.isAfter(cooldown.until!)) {
      cooldown.until = candidate;
    }
  }

  Future<_HostCooldownPermit> acquire(
    String host,
    QuizImageCancellation cancellation, {
    required DateTime? deadline,
  }) async {
    final cooldown = _hosts[host];
    if (cooldown == null ||
        (cooldown.queued == 0 &&
            !cooldown.requiresPermit &&
            (cooldown.until == null || !cooldown.until!.isAfter(_now())))) {
      return const _HostCooldownPermit.noop();
    }

    cooldown.queued++;
    final generation = cooldown.generation;
    final previous = cooldown.tail;
    final release = Completer<void>();
    cooldown.tail = release.future;
    var released = false;
    void releasePermit() {
      if (released) return;
      released = true;
      cooldown.queued--;
      if (!release.isCompleted) release.complete();
      if (cooldown.queued == 0 &&
          cooldown.generation == generation &&
          (cooldown.until == null || !cooldown.until!.isAfter(_now()))) {
        cooldown.requiresPermit = false;
        _hosts.remove(host);
      }
    }

    try {
      await cancellation.wait(previous);
      while (cooldown.until?.isAfter(_now()) ?? false) {
        final delay = cooldown.until!.difference(_now());
        if (deadline != null) {
          final remaining = deadline.difference(_now());
          if (remaining <= Duration.zero || delay >= remaining) {
            throw const QuizImagePreparationException(QuizImageFailure.timeout);
          }
        }
        await cancellation.wait(Future<void>.delayed(delay));
      }
      cancellation.check();
      return _HostCooldownPermit(releasePermit);
    } catch (_) {
      releasePermit();
      rethrow;
    }
  }
}

final class _HostCooldown {
  DateTime? until;
  Future<void> tail = Future<void>.value();
  int queued = 0;
  int generation = 0;
  bool requiresPermit = false;
}

final class _HostCooldownPermit {
  const _HostCooldownPermit.noop() : _release = null;
  const _HostCooldownPermit(this._release);

  final void Function()? _release;
  void release() => _release?.call();
}
