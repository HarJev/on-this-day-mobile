import 'package:sqflite/sqflite.dart';

import '../../domain/quiz_definition.dart';
import '../../domain/quiz_exceptions.dart';
import '../../domain/quiz_result.dart';
import '../../domain/quiz_result_store.dart';
import 'quiz_database.dart';
import 'quiz_result_snapshot_codec.dart';

/// Durable result store. Receipts are immutable idempotency records; snapshots
/// only remain while an official or best-result reference requires review data.
final class SqliteQuizResultStore implements QuizResultStore {
  SqliteQuizResultStore({
    QuizDatabase? database,
    QuizResultSnapshotCodec? codec,
  }) : _database = database ?? QuizDatabase(),
       _codec = codec ?? const QuizResultSnapshotCodec();

  final QuizDatabase _database;
  final QuizResultSnapshotCodec _codec;

  @override
  Future<StoredQuizResult?> getOfficialDaily(QuizDate date) async {
    try {
      final database = await _database.open();
      final rows = await database.rawQuery(
        '''
        SELECT receipt.snapshot_version, receipt.fingerprint, receipt.save_intent,
               receipt.classification, snapshot.snapshot_json
        FROM official_daily_result AS official
        JOIN result_snapshot AS snapshot ON snapshot.completion_id = official.completion_id
        JOIN completion_receipt AS receipt ON receipt.completion_id = official.completion_id
        WHERE official.backend_date = ?
      ''',
        [date.isoDate],
      );
      if (rows.isEmpty) return null;
      if (rows.length != 1) {
        throw const QuizStorageCorruptionException(
          'Multiple official results were stored for one date.',
        );
      }
      final stored = _decodeStored(rows.single);
      final result = stored.result;
      if (stored.classification != QuizSavedClassification.official ||
          result.definition is! DailyQuizDefinition ||
          (result.definition as DailyQuizDefinition).date != date) {
        throw const QuizStorageCorruptionException(
          'Official Daily result does not match its date.',
        );
      }
      return stored;
    } on QuizStorageException {
      rethrow;
    } catch (error) {
      throw QuizStorageException(
        'Could not read the official Daily result.',
        cause: error,
      );
    }
  }

  @override
  Future<StoredQuizResult> saveCompletion(QuizCompletion completion) async {
    final fingerprint = _codec.fingerprint(completion.result);
    final snapshot = _codec.encode(completion.result);
    try {
      final database = await _database.open();
      return database.transaction((transaction) async {
        final existing = await transaction.query(
          'completion_receipt',
          columns: ['fingerprint', 'save_intent', 'classification'],
          where: 'completion_id = ?',
          whereArgs: [completion.result.completionId],
        );
        if (existing.isNotEmpty) {
          final receipt = existing.single;
          if (receipt['fingerprint'] != fingerprint ||
              receipt['save_intent'] != completion.intent.name) {
            throw const QuizCompletionConflictException(
              'A completion ID was reused with a different result or save intent.',
            );
          }
          return StoredQuizResult(
            completion.result,
            _classification(receipt['classification']),
          );
        }

        final classification = await _classificationFor(
          transaction,
          completion,
        );
        final effectiveIntent = _effectiveIntent(completion, classification);
        await transaction.insert('completion_receipt', {
          'completion_id': completion.result.completionId,
          'snapshot_version': QuizResultSnapshotCodec.version,
          'fingerprint': fingerprint,
          'save_intent': effectiveIntent.name,
          'classification': classification.name,
        });
        await transaction.insert('result_snapshot', {
          'completion_id': completion.result.completionId,
          'snapshot_json': snapshot,
        });
        if (classification == QuizSavedClassification.official) {
          final daily = completion.result.definition as DailyQuizDefinition;
          await transaction.insert('official_daily_result', {
            'backend_date': daily.date.isoDate,
            'completion_id': completion.result.completionId,
          });
        } else {
          await _saveBest(transaction, completion.result);
        }
        await _deleteUnreferencedSnapshots(transaction);
        return StoredQuizResult(completion.result, classification);
      });
    } on QuizStorageException {
      rethrow;
    } catch (error) {
      throw QuizStorageException(
        'Could not save the quiz result.',
        cause: error,
      );
    }
  }

  @override
  Future<StoredQuizResult?> getBestResult(QuizBestResultKey key) async {
    try {
      final database = await _database.open();
      final address = _bestAddress(key);
      final rows = await database.rawQuery(
        '''
        SELECT best.mode, best.scope_key, best.question_count, best.timing_enabled,
               best.correct_count, receipt.snapshot_version, receipt.fingerprint,
               receipt.save_intent, receipt.classification, snapshot.snapshot_json
        FROM best_quiz_result AS best
        JOIN result_snapshot AS snapshot ON snapshot.completion_id = best.completion_id
        JOIN completion_receipt AS receipt ON receipt.completion_id = best.completion_id
        WHERE best.mode = ? AND best.scope_key = ? AND best.question_count = ? AND best.timing_enabled = ?
      ''',
        [
          address.mode,
          address.scopeKey,
          key.questionCount,
          key.timingEnabled ? 1 : 0,
        ],
      );
      if (rows.isEmpty) return null;
      if (rows.length != 1) {
        throw const QuizStorageCorruptionException(
          'Multiple best results were stored for one key.',
        );
      }
      final row = rows.single;
      final stored = _decodeStored(row);
      if (row['correct_count'] != stored.result.correct ||
          !_matchesBestKey(stored, key)) {
        throw const QuizStorageCorruptionException(
          'Best-result metadata does not match its snapshot.',
        );
      }
      return stored;
    } on QuizStorageException {
      rethrow;
    } catch (error) {
      throw QuizStorageException(
        'Could not read the best quiz result.',
        cause: error,
      );
    }
  }

  @override
  Future<bool> getQuickPlayTimingEnabled() async {
    try {
      final database = await _database.open();
      final rows = await database.query(
        'quiz_preferences',
        where: 'singleton = 1',
      );
      return rows.isEmpty || rows.single['quick_play_timing_enabled'] == 1;
    } catch (error) {
      throw QuizStorageException(
        'Could not read the Quick Play timing preference.',
        cause: error,
      );
    }
  }

  @override
  Future<void> setQuickPlayTimingEnabled(bool enabled) async {
    try {
      final database = await _database.open();
      await database.insert('quiz_preferences', {
        'singleton': 1,
        'quick_play_timing_enabled': enabled ? 1 : 0,
      }, conflictAlgorithm: ConflictAlgorithm.replace);
    } catch (error) {
      throw QuizStorageException(
        'Could not save the Quick Play timing preference.',
        cause: error,
      );
    }
  }

  Future<QuizSavedClassification> _classificationFor(
    Transaction transaction,
    QuizCompletion completion,
  ) async {
    if (completion.result.definition is QuickPlayQuizDefinition) {
      return QuizSavedClassification.quickPlay;
    }
    if (completion.intent == QuizSaveIntent.practice) {
      return QuizSavedClassification.practice;
    }
    final date =
        (completion.result.definition as DailyQuizDefinition).date.isoDate;
    final occupied = await transaction.query(
      'official_daily_result',
      columns: ['backend_date'],
      where: 'backend_date = ?',
      whereArgs: [date],
    );
    return occupied.isEmpty
        ? QuizSavedClassification.official
        : QuizSavedClassification.practice;
  }

  QuizSaveIntent _effectiveIntent(
    QuizCompletion completion,
    QuizSavedClassification classification,
  ) => switch (classification) {
    QuizSavedClassification.official => QuizSaveIntent.claimDailyIfAbsent,
    QuizSavedClassification.practice => QuizSaveIntent.practice,
    QuizSavedClassification.quickPlay => QuizSaveIntent.quickPlay,
  };

  Future<void> _saveBest(Transaction transaction, QuizResult result) async {
    final key = _keyForResult(result);
    final address = _bestAddress(key);
    final existing = await transaction.query(
      'best_quiz_result',
      where:
          'mode = ? AND scope_key = ? AND question_count = ? AND timing_enabled = ?',
      whereArgs: [
        address.mode,
        address.scopeKey,
        key.questionCount,
        key.timingEnabled ? 1 : 0,
      ],
    );
    if (existing.isNotEmpty &&
        (existing.single['correct_count'] as int) >= result.correct) {
      return;
    }
    await transaction.insert('best_quiz_result', {
      'mode': address.mode,
      'scope_key': address.scopeKey,
      'question_count': key.questionCount,
      'timing_enabled': key.timingEnabled ? 1 : 0,
      'correct_count': result.correct,
      'completion_id': result.completionId,
    }, conflictAlgorithm: ConflictAlgorithm.replace);
  }

  Future<void> _deleteUnreferencedSnapshots(Transaction transaction) =>
      transaction.execute('''
    DELETE FROM result_snapshot
    WHERE completion_id NOT IN (SELECT completion_id FROM official_daily_result)
      AND completion_id NOT IN (SELECT completion_id FROM best_quiz_result)
  ''');

  StoredQuizResult _decodeStored(Map<String, Object?> row) {
    final encoded = row['snapshot_json'];
    final fingerprint = row['fingerprint'];
    if (row['snapshot_version'] != QuizResultSnapshotCodec.version ||
        encoded is! String ||
        fingerprint is! String ||
        _codec.fingerprintEncoded(encoded) != fingerprint) {
      throw const QuizStorageCorruptionException(
        'Stored quiz result fingerprint does not match its receipt.',
      );
    }
    final classification = _classification(row['classification']);
    if (row['save_intent'] != _intentFor(classification).name) {
      throw const QuizStorageCorruptionException(
        'Stored quiz result intent does not match its classification.',
      );
    }
    return StoredQuizResult(_codec.decode(encoded), classification);
  }

  QuizSaveIntent _intentFor(QuizSavedClassification classification) =>
      switch (classification) {
        QuizSavedClassification.official => QuizSaveIntent.claimDailyIfAbsent,
        QuizSavedClassification.practice => QuizSaveIntent.practice,
        QuizSavedClassification.quickPlay => QuizSaveIntent.quickPlay,
      };

  QuizSavedClassification _classification(Object? value) {
    if (value is! String) {
      throw const QuizStorageCorruptionException(
        'Stored quiz result has an invalid classification.',
      );
    }
    return QuizSavedClassification.values
            .where((item) => item.name == value)
            .singleOrNull ??
        (throw const QuizStorageCorruptionException(
          'Stored quiz result has an unknown classification.',
        ));
  }

  _BestAddress _bestAddress(QuizBestResultKey key) => key.date != null
      ? _BestAddress('daily', 'daily:${key.date!.isoDate}')
      : _BestAddress(
          'quickPlay',
          key.collectionId == null ? 'mixed' : 'collection:${key.collectionId}',
        );

  QuizBestResultKey _keyForResult(QuizResult result) =>
      switch (result.definition) {
        DailyQuizDefinition(:final date, :final questionCount) =>
          QuizBestResultKey.daily(date, questionCount),
        QuickPlayQuizDefinition(:final selection, :final questionCount) =>
          QuizBestResultKey.quickPlay(
            questionCount: questionCount,
            timingEnabled: result.timingEnabled,
            collectionId: selection.collectionId,
          ),
      };

  bool _matchesBestKey(StoredQuizResult stored, QuizBestResultKey key) {
    final result = stored.result;
    if (result.correct < 0 || result.timingEnabled != key.timingEnabled) {
      return false;
    }
    if (result.definition case DailyQuizDefinition(
      :final date,
      :final questionCount,
    )) {
      return key.date == date &&
          key.questionCount == questionCount &&
          stored.classification == QuizSavedClassification.practice;
    }
    if (result.definition case QuickPlayQuizDefinition(
      :final selection,
      :final questionCount,
    )) {
      return key.date == null &&
          key.collectionId == selection.collectionId &&
          key.questionCount == questionCount &&
          stored.classification == QuizSavedClassification.quickPlay;
    }
    return false;
  }
}

final class _BestAddress {
  const _BestAddress(this.mode, this.scopeKey);
  final String mode;
  final String scopeKey;
}
