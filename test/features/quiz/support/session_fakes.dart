import 'dart:async';
import 'dart:ui' as ui;
import 'package:flutter_test/flutter_test.dart';
import 'package:on_this_day_mobile/features/quiz/presentation/images/prepared_quiz_images.dart';

import 'package:on_this_day_mobile/features/quiz/domain/quiz_definition.dart';
import 'package:on_this_day_mobile/features/quiz/domain/quiz_image.dart';
import 'package:on_this_day_mobile/features/quiz/domain/quiz_question.dart';
import 'package:on_this_day_mobile/features/quiz/domain/quiz_rules.dart';
import 'package:on_this_day_mobile/features/quiz/domain/quiz_source.dart';
import 'package:on_this_day_mobile/features/quiz/presentation/quiz_session_clock.dart';
import 'package:on_this_day_mobile/features/quiz/presentation/quiz_session_preparation.dart';
import 'package:on_this_day_mobile/features/quiz/presentation/quiz_session_scheduler.dart';

final class FakeSessionClock implements QuizSessionClock {
  @override
  Duration elapsed = Duration.zero;
  @override
  DateTime utcNow = DateTime.utc(2026, 9, 13);
  void advance(Duration duration, {Duration? wall}) {
    elapsed += duration;
    utcNow = utcNow.add(wall ?? duration);
  }
}

final class FakeScheduledTick {
  FakeScheduledTick(this.callback);
  final void Function() callback;
  bool cancelled = false;
}

final class FakeSessionScheduler implements QuizSessionScheduler {
  final List<FakeScheduledTick> ticks = [];
  int get activeCount => ticks.where((t) => !t.cancelled).length;
  @override
  void Function() schedule(void Function() tick) {
    final scheduled = FakeScheduledTick(tick);
    ticks.add(scheduled);
    return () => scheduled.cancelled = true;
  }

  void fire() {
    for (final tick in ticks.toList()) {
      if (!tick.cancelled) tick.callback();
    }
  }
}

final class FakePreparation {
  final List<Completer<QuizPreparedResources>> pending = [];
  int cancellations = 0, releases = 0;
  QuizPreparationAttempt call(QuizDefinition _) {
    final completion = Completer<QuizPreparedResources>();
    pending.add(completion);
    return QuizPreparationAttempt(
      completion.future,
      onCancel: () => cancellations++,
    );
  }

  QuizPreparedResources succeed([int? index]) {
    final resources = QuizPreparedResources(
      () => releases++,
      images: PreparedQuizImages(
        {
          for (var i = 0; i < 5; i++)
            'q-$i': Uri.parse('https://example.org/fake-$i'),
        },
        {
          for (var i = 0; i < 5; i++)
            Uri.parse('https://example.org/fake-$i'): _ControllerTestImage(),
        },
      ),
    );
    pending[index ?? pending.length - 1].complete(resources);
    return resources;
  }
}

/// No pixel rendering in the original controller harness; MQ5 tests use real bytes.
class _ControllerTestImage extends Fake implements ui.Image {
  @override
  ui.Image clone() => _ControllerTestImage();
  @override
  void dispose() {}
}

List<QuizQuestion> sessionQuestions({
  QuizQuestionType last = QuizQuestionType.multipleChoice,
}) => [
  for (var i = 0; i < 5; i++)
    sessionQuestion(i, i == 4 ? last : QuizQuestionType.values[i]),
];

QuizQuestion sessionQuestion(int i, QuizQuestionType type) {
  final source = QuizSource(
    displayName: 'Test museum',
    url: Uri.parse('https://example.org/source'),
  );
  final options = [
    for (final id in ['a', 'b', 'c', 'd']) QuizOption(id, 'Option $id'),
  ];
  final id = 'q-$i';
  const prompt = 'Which answer matches this question?';
  const explanation = 'The reviewed explanation.';
  switch (type) {
    case QuizQuestionType.multipleChoice:
      return MultipleChoiceQuestion(
        id: id,
        difficulty: QuizDifficulty.easy,
        prompt: prompt,
        explanation: explanation,
        sources: [source],
        options: options,
        correctOptionId: 'a',
      );
    case QuizQuestionType.trueFalse:
      return TrueFalseQuestion(
        id: id,
        difficulty: QuizDifficulty.easy,
        prompt: prompt,
        explanation: explanation,
        sources: [source],
        options: [QuizOption('true', 'True'), QuizOption('false', 'False')],
        correctOptionId: 'true',
      );
    case QuizQuestionType.imageIdentification:
      return ImageIdentificationQuestion(
        id: id,
        difficulty: QuizDifficulty.easy,
        prompt: prompt,
        explanation: explanation,
        sources: [source],
        options: options,
        correctOptionId: 'a',
        image: QuizImage(
          url: Uri.parse('https://example.org/image'),
          altText: 'An archival object',
          source: 'Museum',
          sourceUrl: source.url,
          attribution: 'Museum',
          license: 'CC0',
          licenseUrl: Uri.parse('https://example.org/license'),
        ),
      );
    case QuizQuestionType.chronologicalOrdering:
      return ChronologicalOrderingQuestion(
        id: id,
        difficulty: QuizDifficulty.easy,
        prompt: prompt,
        explanation: explanation,
        sources: [source],
        items: [
          for (final id in ['d', 'b', 'a', 'c'])
            QuizOrderingItem(id, 'Item $id'),
        ],
        correctOrderItemIds: ['a', 'b', 'c', 'd'],
      );
  }
}

QuizDefinition sessionQuiz({
  bool daily = false,
  Duration limit = const Duration(seconds: 20),
  QuizQuestionType last = QuizQuestionType.multipleChoice,
}) {
  final questions = sessionQuestions(last: last);
  if (daily) {
    return DailyQuizDefinition(
      questionCount: 5,
      questions: questions,
      challengeId: 'daily-2026-09-13',
      date: QuizDate('2026-09-13'),
      displayDate: 'Sep 13',
      duration: limit,
    );
  }
  return QuickPlayQuizDefinition(
    questionCount: 5,
    questions: questions,
    selection: QuizSelection(displayName: 'Mixed'),
    questionTimeLimits: {for (final q in questions) q.id: limit},
    timingEnabledByDefault: true,
  );
}
