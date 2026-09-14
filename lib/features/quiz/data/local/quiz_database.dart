import 'package:path/path.dart' as path;
import 'package:sqflite/sqflite.dart';

/// Lazily opens the app-owned quiz database. Nothing constructs this from the
/// Today startup path, so a local database problem cannot block content loads.
final class QuizDatabase {
  QuizDatabase({Future<String> Function()? databasePath})
    : _databasePath = databasePath ?? _defaultPath;

  final Future<String> Function() _databasePath;
  Future<Database>? _opening;

  Future<Database> open() => _opening ??= _open();

  Future<Database> _open() async {
    final file = await _databasePath();
    return openDatabase(
      file,
      version: 2,
      onConfigure: (database) async {
        await database.execute('PRAGMA foreign_keys = ON');
      },
      onCreate: (database, version) async {
        await createV1(database);
        if (version >= 2) await upgradeToV2(database);
      },
      onUpgrade: (database, from, to) async {
        if (from < 2 && to >= 2) await upgradeToV2(database);
      },
    );
  }

  static Future<String> _defaultPath() async =>
      path.join(await getDatabasesPath(), 'on_this_day_quiz.db');

  static Future<void> createV1(DatabaseExecutor database) async {
    await database.execute('''
      CREATE TABLE completion_receipt (
        completion_id TEXT PRIMARY KEY NOT NULL,
        snapshot_version INTEGER NOT NULL,
        fingerprint TEXT NOT NULL,
        save_intent TEXT NOT NULL CHECK (save_intent IN ('claimDailyIfAbsent', 'practice', 'quickPlay')),
        classification TEXT NOT NULL CHECK (classification IN ('official', 'practice', 'quickPlay'))
      )
    ''');
    await database.execute('''
      CREATE TABLE result_snapshot (
        completion_id TEXT PRIMARY KEY NOT NULL,
        snapshot_json TEXT NOT NULL,
        FOREIGN KEY (completion_id) REFERENCES completion_receipt(completion_id) ON DELETE RESTRICT
      )
    ''');
    await database.execute('''
      CREATE TABLE official_daily_result (
        backend_date TEXT PRIMARY KEY NOT NULL,
        completion_id TEXT UNIQUE NOT NULL,
        FOREIGN KEY (completion_id) REFERENCES result_snapshot(completion_id) ON DELETE RESTRICT
      )
    ''');
    await database.execute('''
      CREATE TABLE best_quiz_result (
        mode TEXT NOT NULL CHECK (mode IN ('daily', 'quickPlay')),
        scope_key TEXT NOT NULL,
        question_count INTEGER NOT NULL,
        timing_enabled INTEGER NOT NULL CHECK (timing_enabled IN (0, 1)),
        correct_count INTEGER NOT NULL,
        completion_id TEXT NOT NULL,
        PRIMARY KEY (mode, scope_key, question_count, timing_enabled),
        FOREIGN KEY (completion_id) REFERENCES result_snapshot(completion_id) ON DELETE RESTRICT
      )
    ''');
  }

  static Future<void> upgradeToV2(DatabaseExecutor database) =>
      database.execute('''
    CREATE TABLE IF NOT EXISTS quiz_preferences (
      singleton INTEGER PRIMARY KEY NOT NULL CHECK (singleton = 1),
      quick_play_timing_enabled INTEGER NOT NULL CHECK (quick_play_timing_enabled IN (0, 1))
    )
  ''');
}
