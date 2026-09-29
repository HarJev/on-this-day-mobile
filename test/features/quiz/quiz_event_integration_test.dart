import 'dart:convert';
import 'dart:io';
import 'dart:ui' as ui;

import 'package:crypto/crypto.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:on_this_day_mobile/core/config/app_theme.dart';
import 'package:on_this_day_mobile/core/navigation/source_launcher.dart';
import 'package:on_this_day_mobile/features/on_this_day/data/dto/event_detail_response.dart';
import 'package:on_this_day_mobile/features/quiz/data/dto/daily_quiz_response.dart';
import 'package:on_this_day_mobile/features/quiz/data/dto/quick_play_response.dart';
import 'package:on_this_day_mobile/features/quiz/data/local/quiz_result_snapshot_codec.dart';
import 'package:on_this_day_mobile/features/quiz/domain/question_outcome.dart';
import 'package:on_this_day_mobile/features/quiz/domain/quiz_answer.dart';
import 'package:on_this_day_mobile/features/quiz/domain/quiz_definition.dart';
import 'package:on_this_day_mobile/features/quiz/domain/quiz_question.dart';
import 'package:on_this_day_mobile/features/quiz/domain/quiz_result.dart';
import 'package:on_this_day_mobile/features/quiz/presentation/quiz_full_review_screen.dart';

import '../../support/capture_fonts.dart';
import 'support/session_fakes.dart';
import 'package:on_this_day_mobile/features/quiz/presentation/quiz_gameplay_view.dart';
import 'package:on_this_day_mobile/features/quiz/presentation/quiz_session_controller.dart';
import 'package:on_this_day_mobile/features/quiz/presentation/quiz_session_preparation.dart';
import 'data/quiz_api_fixtures.dart';

void main() {
  const codec = QuizResultSnapshotCodec();

  test(
    'all four shapes preserve explicit links in both API modes and snapshots',
    () {
      for (final json in [quickJson(), dailyJson()]) {
        _addLinks(json);
        final QuizDefinition definition = json['mode'] == 'daily'
            ? DailyQuizResponse.fromJson(json).toDomain()
            : QuickPlayResponse.fromJson(json).toDomain();
        final result = _result(definition);
        final decoded = codec.decode(codec.encode(result));
        for (var i = 0; i < definition.questions.length; i++) {
          expect(
            decoded.definition.questions[i].relatedEvents.single.id,
            'event-$i',
          );
          expect(
            decoded.definition.questions[i].relatedEvents.single.year,
            '1958',
          );
          expect(
            () => decoded.definition.questions[i].relatedEvents.clear(),
            throwsUnsupportedError,
          );
        }
        expect(
          codec.fingerprintEncoded(codec.encode(result)),
          codec.fingerprint(result),
        );
      }
    },
  );

  test('legacy snapshots retain their canonical bytes and SHA-256 receipt', () {
    final definition = QuickPlayResponse.fromJson(quickJson()).toDomain();
    final encoded = codec.encode(_result(definition));
    expect(encoded, isNot(contains('relatedEvents')));
    expect(codec.encode(codec.decode(encoded)), encoded);
    expect(
      codec.fingerprintEncoded(encoded),
      sha256.convert(utf8.encode(encoded)).toString(),
    );
    expect(
      codec
          .decode(encoded)
          .definition
          .questions
          .every((q) => q.relatedEvents.isEmpty),
      isTrue,
    );
  });

  test(
    'present malformed links and duplicate IDs are rejected, not hidden',
    () {
      for (final value in [
        null,
        'event',
        [
          <String, Object?>{'id': 'bad/id', 'title': 'Story', 'year': '1958'},
        ],
        [
          <String, Object?>{'id': 'event', 'title': 'Story', 'year': '1958'},
          <String, Object?>{'id': 'event', 'title': 'Story', 'year': '1958'},
        ],
      ]) {
        final json = quickJson();
        (json['questions'] as List).first['relatedEvents'] = value;
        expect(
          () => QuickPlayResponse.fromJson(json).toDomain(),
          throwsA(isA<Exception>()),
        );
      }
    },
  );

  test(
    'event eligibility is optional on older APIs and strictly boolean when present',
    () {
      final json = <String, Object?>{
        'id': 'event',
        'title': 'Story',
        'year': '1958',
        'historicalDate': 'October 1, 1958',
        'summary': 'Summary',
        'description': 'Description',
        'sources': [
          {'name': 'Museum', 'url': 'https://example.org'},
        ],
        'images': [],
      };
      expect(
        EventDetailResponse.fromJson(json).toDomain().hasRelatedQuizQuestions,
        isFalse,
      );
      json['hasRelatedQuizQuestions'] = true;
      expect(
        EventDetailResponse.fromJson(json).toDomain().hasRelatedQuizQuestions,
        isTrue,
      );
      for (final invalid in [null, 1, 'true']) {
        json['hasRelatedQuizQuestions'] = invalid;
        expect(() => EventDetailResponse.fromJson(json), throwsFormatException);
      }
    },
  );

  testWidgets('linked titles never appear in answering or feedback gameplay', (
    tester,
  ) async {
    final json = quickJson();
    _addLinks(json);
    final controller = QuizSessionController(
      definition: QuickPlayResponse.fromJson(json).toDomain(),
      completionId: 'no-spoilers',
      timingEnabled: false,
      clock: FakeSessionClock(),
      scheduler: FakeSessionScheduler(),
      prepareSession: (_) =>
          QuizPreparationAttempt(Future.value(QuizPreparedResources(() {}))),
      completionSink: (_) async {},
    );
    addTearDown(controller.dispose);
    await controller.prepare();
    controller.start();
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.light,
        home: QuizGameplayView(
          controller: controller,
          sourceLauncher: _Launcher(),
          onExit: () {},
          onViewResults: (_) {},
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.textContaining('NASA begins operations'), findsNothing);
    expect(find.text('Related history'), findsNothing);
    controller.answerOption('question-0', 'a');
    await tester.pumpAndSettle();
    expect(find.textContaining('NASA begins operations'), findsNothing);
    expect(find.text('Related history'), findsNothing);
  });

  for (final scale in [1.0, 2.0]) {
    testWidgets(
      'completed review story navigation retains state at ${scale}x text',
      (tester) async {
        tester.view.physicalSize = const Size(390, 844);
        tester.view.devicePixelRatio = 1;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);
        final json = quickJson();
        _addLinks(json);
        final result = _result(QuickPlayResponse.fromJson(json).toDomain());
        final captureKey = GlobalKey();
        final navigatorKey = GlobalKey<NavigatorState>();
        final folder = Platform.environment['QUIZ_EVENT_CAPTURE_DIR'];
        if (folder != null) await loadCaptureFonts(tester);
        String? opened;
        await tester.pumpWidget(
          MaterialApp(
            theme: AppTheme.light,
            navigatorKey: navigatorKey,
            builder: (context, child) => MediaQuery(
              data: MediaQuery.of(
                context,
              ).copyWith(textScaler: TextScaler.linear(scale)),
              child: child!,
            ),
            home: RepaintBoundary(
              key: captureKey,
              child: QuizFullReviewScreen(
                result: result,
                sourceLauncher: _Launcher(),
                onDone: () {},
                onOpenEvent: (id) {
                  opened = id;
                  navigatorKey.currentState!.push(
                    MaterialPageRoute<void>(
                      builder: (_) => Scaffold(
                        appBar: AppBar(title: const Text('Story')),
                        body: const Text('Historical event detail'),
                      ),
                    ),
                  );
                },
              ),
            ),
          ),
        );
        await tester.pumpAndSettle();
        final disclosure = find.byKey(
          const ValueKey('question-0:related-history'),
        );
        await tester.ensureVisible(disclosure);
        await tester.pumpAndSettle();
        await tester.tap(
          find.descendant(
            of: disclosure,
            matching: find.text('Related history'),
          ),
        );
        await tester.pumpAndSettle();
        final story = find.byKey(const ValueKey('related-event-event-0'));
        await tester.ensureVisible(story);
        await tester.pumpAndSettle();
        expect(
          find.text(
            'NASA begins operations and opens a new chapter in space exploration',
          ),
          findsOneWidget,
        );
        expect(tester.takeException(), isNull);
        await tester.tap(story);
        await tester.pumpAndSettle();
        expect(opened, 'event-0');
        navigatorKey.currentState!.pop();
        await tester.pumpAndSettle();
        expect(story, findsOneWidget);
        expect(tester.takeException(), isNull);
        if (folder != null) {
          await tester.runAsync(() async {
            final image =
                await (captureKey.currentContext!.findRenderObject()
                        as RenderRepaintBoundary)
                    .toImage();
            final bytes = await image.toByteData(
              format: ui.ImageByteFormat.png,
            );
            await Directory(folder).create(recursive: true);
            await File(
              '$folder/review-${scale}x.png',
            ).writeAsBytes(bytes!.buffer.asUint8List());
            image.dispose();
          });
        }
      },
    );
  }
}

void _addLinks(Map<String, Object?> json) {
  final questions = json['questions'] as List;
  for (var i = 0; i < questions.length; i++) {
    questions[i]['relatedEvents'] = [
      <String, Object?>{
        'id': 'event-$i',
        'title':
            'NASA begins operations and opens a new chapter in space exploration',
        'year': '1958',
      },
    ];
  }
}

QuizResult _result(QuizDefinition definition) => QuizResult(
  completionId: 'related-history-completion',
  definition: definition,
  timingEnabled: true,
  completedAt: DateTime.utc(2026, 9, 28),
  reason: QuizCompletionReason.questionsFinished,
  outcomes: [
    for (final question in definition.questions)
      QuestionOutcome.answered(
        question,
        question is ChoiceQuestion
            ? OptionAnswer(question.correctOptionId)
            : OrderingAnswer(
                (question as ChronologicalOrderingQuestion).correctOrderItemIds,
              ),
      ),
  ],
);

class _Launcher implements SourceLauncher {
  @override
  Future<bool> open(Uri uri) async => true;
}
