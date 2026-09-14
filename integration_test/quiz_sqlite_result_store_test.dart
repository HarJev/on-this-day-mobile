import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:on_this_day_mobile/features/quiz/data/local/quiz_database.dart';
import 'package:on_this_day_mobile/features/quiz/data/local/sqlite_quiz_result_store.dart';
import 'package:on_this_day_mobile/features/quiz/domain/question_outcome.dart';
import 'package:on_this_day_mobile/features/quiz/domain/quiz_answer.dart';
import 'package:on_this_day_mobile/features/quiz/domain/quiz_definition.dart';
import 'package:on_this_day_mobile/features/quiz/domain/quiz_exceptions.dart';
import 'package:on_this_day_mobile/features/quiz/domain/quiz_question.dart';
import 'package:on_this_day_mobile/features/quiz/domain/quiz_result.dart';
import 'package:path/path.dart' as path;
import 'package:sqflite/sqflite.dart';

import '../test/features/quiz/support/session_fakes.dart';

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  late String databasePath;
  late QuizDatabase database;
  late SqliteQuizResultStore store;

  setUp(() async {
    databasePath = path.join(
      await getDatabasesPath(),
      'mq7-${DateTime.now().microsecondsSinceEpoch}.db',
    );
    database = QuizDatabase(databasePath: () async => databasePath);
    store = SqliteQuizResultStore(database: database);
  });

  tearDown(() => deleteDatabase(databasePath));

  testWidgets('persists one official Daily result and retries idempotently', (
    tester,
  ) async {
    final completion = _dailyCompletion('official', correctCount: 4);

    final first = await store.saveCompletion(completion);
    final retry = await store.saveCompletion(completion);
    final official = await store.getOfficialDaily(
      (completion.result.definition as DailyQuizDefinition).date,
    );

    expect(first.classification, QuizSavedClassification.official);
    expect(retry.classification, QuizSavedClassification.official);
    expect(official!.result.completionId, 'official');
  });

  testWidgets('keeps official Daily separate from the strict practice best', (
    tester,
  ) async {
    await store.saveCompletion(_dailyCompletion('official', correctCount: 2));
    final practice = await store.saveCompletion(
      _dailyCompletion('practice-one', correctCount: 3, practice: true),
    );
    await store.saveCompletion(
      _dailyCompletion('practice-tie', correctCount: 3, practice: true),
    );
    final daily = sessionQuiz(daily: true) as DailyQuizDefinition;
    final best = await store.getBestResult(
      QuizBestResultKey.daily(daily.date, daily.questionCount),
    );
    final official = await store.getOfficialDaily(daily.date);

    expect(practice.classification, QuizSavedClassification.practice);
    expect(best!.result.completionId, 'practice-one');
    expect(official!.result.completionId, 'official');
  });

  testWidgets('uses foreign keys and reports durable corruption distinctly', (
    tester,
  ) async {
    final completion = _dailyCompletion('official', correctCount: 5);
    await store.saveCompletion(completion);
    final raw = await database.open();

    await expectLater(
      raw.delete(
        'result_snapshot',
        where: 'completion_id = ?',
        whereArgs: ['official'],
      ),
      throwsA(isA<DatabaseException>()),
    );
    await raw.update(
      'completion_receipt',
      {'fingerprint': 'not-a-real-fingerprint'},
      where: 'completion_id = ?',
      whereArgs: ['official'],
    );
    await expectLater(
      store.getOfficialDaily(
        (completion.result.definition as DailyQuizDefinition).date,
      ),
      throwsA(isA<QuizStorageCorruptionException>()),
    );
  });

  testWidgets('upgrades the v1 receipt schema before reading preferences', (
    tester,
  ) async {
    final v1 = await openDatabase(
      databasePath,
      version: 1,
      onConfigure: (database) async =>
          database.execute('PRAGMA foreign_keys = ON'),
      onCreate: (database, _) => QuizDatabase.createV1(database),
    );
    await v1.close();

    await store.setQuickPlayTimingEnabled(false);

    expect(await store.getQuickPlayTimingEnabled(), isFalse);
  });

  testWidgets('rolls back a save when a later write fails', (tester) async {
    final raw = await database.open();
    await raw.execute('DROP TABLE result_snapshot');

    await expectLater(
      store.saveCompletion(_dailyCompletion('rollback', correctCount: 5)),
      throwsA(isA<QuizStorageException>()),
    );
    final receipts = await raw.query(
      'completion_receipt',
      where: 'completion_id = ?',
      whereArgs: ['rollback'],
    );

    expect(receipts, isEmpty);
  });
}

QuizCompletion _dailyCompletion(
  String completionId, {
  required int correctCount,
  bool practice = false,
}) {
  final definition = sessionQuiz(daily: true) as DailyQuizDefinition;
  return QuizCompletion(
    QuizResult(
      completionId: completionId,
      definition: definition,
      timingEnabled: true,
      completedAt: DateTime.utc(2026, 9, 13),
      reason: QuizCompletionReason.questionsFinished,
      outcomes: [
        for (var index = 0; index < definition.questions.length; index++)
          _outcome(definition.questions[index], index < correctCount),
      ],
    ),
    practice ? QuizSaveIntent.practice : QuizSaveIntent.claimDailyIfAbsent,
  );
}

QuestionOutcome _outcome(QuizQuestion question, bool correct) {
  if (question is ChoiceQuestion) {
    return QuestionOutcome.answered(
      question,
      OptionAnswer(correct ? question.correctOptionId : _wrongOption(question)),
    );
  }
  final ordering = question as ChronologicalOrderingQuestion;
  return QuestionOutcome.answered(
    ordering,
    OrderingAnswer(
      correct
          ? ordering.correctOrderItemIds
          : ordering.correctOrderItemIds.reversed.toList(growable: false),
    ),
  );
}

String _wrongOption(ChoiceQuestion question) => question.options
    .firstWhere((option) => option.id != question.correctOptionId)
    .id;
