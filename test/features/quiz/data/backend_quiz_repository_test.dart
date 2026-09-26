import 'dart:async';
import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:on_this_day_mobile/core/api/api_client.dart';
import 'package:on_this_day_mobile/core/api/api_exception.dart';
import 'package:on_this_day_mobile/features/quiz/data/backend_quiz_repository.dart';
import 'package:on_this_day_mobile/features/quiz/domain/quiz_exceptions.dart';

import 'quiz_api_fixtures.dart';

BackendQuizRepository repository(
  Future<http.Response> Function(http.Request) handler, {
  Duration timeout = const Duration(seconds: 20),
}) => BackendQuizRepository(
  apiClient: ApiClient(
    baseUrl: Uri.parse('http://127.0.0.1:3000'),
    httpClient: MockClient(handler),
  ),
  requestTimeout: timeout,
);
TypeMatcher<QuizException> failure(QuizFailureKind kind) => isA<QuizException>()
    .having((e) => e.kind, 'kind', kind)
    .having((e) => e.cause, 'cause', isNotNull);

void main() {
  test('domain mapping failure retains its diagnostic cause', () async {
    final json = quickJson();
    objectsAt(json, 'questions').first['correctOptionId'] = 'missing';
    final repo = repository((_) async => http.Response(jsonEncode(json), 200));
    await expectLater(
      repo.createQuickPlay(questionCount: 5),
      throwsA(
        failure(QuizFailureKind.invalidContent).having(
          (e) => e.cause,
          'domain cause',
          isA<InvalidQuizDefinitionException>(),
        ),
      ),
    );
  });
  for (final body in ['', '[]', 'null']) {
    test('invalid successful root $body is not an empty catalog', () async {
      final repo = repository((_) async => http.Response(body, 200));
      await expectLater(
        repo.getCatalog(),
        throwsA(failure(QuizFailureKind.invalidContent)),
      );
    });
  }
  testWidgets('Daily uses the same bounded request wait', (tester) async {
    final pending = Completer<http.Response>();
    Object? error;
    final repo = repository(
      (_) => pending.future,
      timeout: const Duration(seconds: 1),
    );
    final operation = repo
        .getDaily(timezone: 'UTC', questionCount: 5)
        .then<void>(
          (_) {},
          onError: (Object e) {
            error = e;
          },
        );
    await tester.pump();
    await tester.pump(const Duration(seconds: 1));
    expect(
      error,
      failure(
        QuizFailureKind.request,
      ).having((e) => e.cause, 'timeout', isA<TimeoutException>()),
    );
    pending.complete(http.Response(jsonEncode(dailyJson()), 200));
    await tester.pump();
    await operation;
  });
  test('catalog GET uses existing client and maps availability', () async {
    final repo = repository((request) async {
      expect(request.method, 'GET');
      expect(
        request.url.toString(),
        'http://127.0.0.1:3000/v1/quizzes/catalog',
      );
      expect(request.headers['accept'], 'application/json');
      return http.Response(jsonEncode(catalogJson()), 200);
    });
    final catalog = await repo.getCatalog();
    expect(catalog.mixed.publishedQuestionCount, 60);
    expect(catalog.collections.first.availability.supportedQuestionCounts, [
      5,
      10,
    ]);
  });
  for (final collection in <String?>[null, 'world-history']) {
    for (final count in [5, 10, 20]) {
      test('POST count $count collection $collection', () async {
        final repo = repository((request) async {
          expect(request.method, 'POST');
          expect(request.url.path, '/v1/quizzes/quick-play');
          expect(request.headers['content-type'], 'application/json');
          expect(jsonDecode(request.body), {
            'questionCount': count,
            'collectionId': ?collection,
          });
          return http.Response(
            jsonEncode(quickJson(count: count, collectionId: collection)),
            200,
          );
        });
        final q = await repo.createQuickPlay(
          questionCount: count,
          collectionId: collection,
        );
        expect(q.questionCount, count);
        expect(q.selection.collectionId, collection);
      });
    }
  }
  test('Daily query encodes timezone and preserves backend date', () async {
    final repo = repository((request) async {
      expect(request.method, 'GET');
      expect(request.url.path, '/v1/quizzes/daily');
      expect(request.url.queryParameters, {
        'timezone': 'America/Argentina/Buenos_Aires',
        'questionCount': '5',
      });
      expect(request.url.query, contains('America%2FArgentina%2FBuenos_Aires'));
      return http.Response(jsonEncode(dailyJson()), 200);
    });
    final q = await repo.getDaily(
      timezone: 'America/Argentina/Buenos_Aires',
      questionCount: 5,
    );
    expect(q.date.isoDate, '2026-08-24');
    expect(q.displayDate, 'Aug 24');
    expect(q.challengeId, 'daily-2026-08-24');
  });
  test('invalid caller inputs do not send HTTP', () async {
    final repo = repository((_) async => throw StateError('Must not send'));
    await expectLater(
      repo.createQuickPlay(questionCount: 6),
      throwsA(failure(QuizFailureKind.invalidSelection)),
    );
    await expectLater(
      repo.createQuickPlay(questionCount: 5, collectionId: ''),
      throwsA(failure(QuizFailureKind.invalidSelection)),
    );
    await expectLater(
      repo.getDaily(timezone: ' ', questionCount: 5),
      throwsA(failure(QuizFailureKind.invalidTimezone)),
    );
    await expectLater(
      repo.getDaily(timezone: 'UTC', questionCount: 0),
      throwsA(failure(QuizFailureKind.invalidSelection)),
    );
  });
  for (final scenario in [
    (400, 'invalid_quiz_request', QuizFailureKind.request),
    (400, 'invalid_timezone', QuizFailureKind.invalidTimezone),
    (400, 'insufficient_quiz_questions', QuizFailureKind.invalidSelection),
    (404, 'quiz_collection_not_found', QuizFailureKind.invalidSelection),
    (503, 'quiz_unavailable', QuizFailureKind.unavailable),
    (500, 'quiz_unavailable', QuizFailureKind.request),
    (400, 'quiz_collection_not_found', QuizFailureKind.request),
    (503, 'unknown', QuizFailureKind.request),
  ]) {
    test('HTTP ${scenario.$1} ${scenario.$2} uses status AND code', () async {
      final repo = repository(
        (_) async => http.Response(
          jsonEncode({
            'code': scenario.$2,
            'message': 'private backend detail',
          }),
          scenario.$1,
        ),
      );
      await expectLater(
        repo.getCatalog(),
        throwsA(
          failure(scenario.$3)
              .having(
                (e) => e.message,
                'safe message',
                isNot(contains('private')),
              )
              .having(
                (e) => (e.cause as ApiException).statusCode,
                'status',
                scenario.$1,
              ),
        ),
      );
    });
  }
  for (final status in [200, 503]) {
    test(
      'malformed JSON at $status is invalidContent, preserving ApiClient behavior',
      () async {
        final repo = repository((_) async => http.Response('{broken', status));
        await expectLater(
          repo.getCatalog(),
          throwsA(
            failure(QuizFailureKind.invalidContent)
                .having(
                  (e) => (e.cause as ApiException).kind,
                  'API kind',
                  ApiExceptionKind.invalidJson,
                )
                .having(
                  (e) => (e.cause as ApiException).cause,
                  'decode cause',
                  isA<FormatException>(),
                ),
          ),
        );
      },
    );
  }
  test('network failure retains original cause chain', () async {
    final error = http.ClientException('transport failure');
    final repo = repository((_) async => throw error);
    await expectLater(
      repo.getCatalog(),
      throwsA(
        failure(QuizFailureKind.request).having(
          (e) => (e.cause as ApiException).cause,
          'original cause',
          same(error),
        ),
      ),
    );
  });
  test('wrong returned count and selection are invalidContent', () async {
    final repo = repository(
      (_) async => http.Response(jsonEncode(quickJson(count: 10)), 200),
    );
    await expectLater(
      repo.createQuickPlay(questionCount: 5),
      throwsA(failure(QuizFailureKind.invalidContent)),
    );
    final wrongSelection = repository(
      (_) async =>
          http.Response(jsonEncode(quickJson(collectionId: 'other')), 200),
    );
    await expectLater(
      wrongSelection.createQuickPlay(questionCount: 5),
      throwsA(failure(QuizFailureKind.invalidContent)),
    );
    final wrongDaily = repository(
      (_) async => http.Response(jsonEncode(dailyJson(count: 10)), 200),
    );
    await expectLater(
      wrongDaily.getDaily(timezone: 'UTC', questionCount: 5),
      throwsA(failure(QuizFailureKind.invalidContent)),
    );
  });
  test('empty object is invalid, genuinely empty catalog is valid', () async {
    final bad = repository((_) async => http.Response('{}', 200));
    await expectLater(
      bad.getCatalog(),
      throwsA(failure(QuizFailureKind.invalidContent)),
    );
    final json = catalogJson();
    json['mixed'] = {
      'publishedQuestionCount': 0,
      'supportedQuestionCounts': <int>[],
    };
    json['collections'] = <Object?>[];
    final good = repository((_) async => http.Response(jsonEncode(json), 200));
    expect((await good.getCatalog()).mixed.publishedQuestionCount, 0);
  });
  test('timeout must be positive', () {
    for (final duration in [Duration.zero, const Duration(seconds: -1)]) {
      expect(
        () => repository(
          (_) async => http.Response('{}', 200),
          timeout: duration,
        ),
        throwsArgumentError,
      );
    }
  });
  testWidgets('default wait ends at 20 seconds; late success is ignored', (
    tester,
  ) async {
    final pending = Completer<http.Response>();
    var completed = false;
    Object? failureValue;
    final repo = repository((_) => pending.future);
    final operation = repo.getCatalog().then<void>(
      (_) {
        completed = true;
      },
      onError: (Object e) {
        failureValue = e;
      },
    );
    await tester.pump();
    await tester.pump(const Duration(seconds: 19));
    expect(failureValue, isNull);
    await tester.pump(const Duration(seconds: 1));
    expect(
      failureValue,
      failure(
        QuizFailureKind.request,
      ).having((e) => e.cause, 'timeout', isA<TimeoutException>()),
    );
    pending.complete(http.Response(jsonEncode(catalogJson()), 200));
    await tester.pump();
    await operation;
    expect(completed, isFalse);
  });
  testWidgets(
    'override applies to POST and late transport error stays handled',
    (tester) async {
      final pending = Completer<http.Response>();
      Object? failureValue;
      final repo = repository(
        (_) => pending.future,
        timeout: const Duration(seconds: 2),
      );
      final operation = repo
          .createQuickPlay(questionCount: 5)
          .then<void>(
            (_) {},
            onError: (Object e) {
              failureValue = e;
            },
          );
      await tester.pump();
      await tester.pump(const Duration(seconds: 2));
      expect(failureValue, failure(QuizFailureKind.request));
      pending.completeError(http.ClientException('late failure'));
      await tester.pump();
      await operation;
    },
  );
}
