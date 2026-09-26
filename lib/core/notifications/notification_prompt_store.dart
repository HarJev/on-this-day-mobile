import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';

/// The user's answer to the in-app notification pre-prompt.
enum NotificationPromptDecision {
  /// The user chose "Not now".
  declined,

  /// The user chose "Turn on notifications" and the system request completed.
  requested,
}

/// Remembers the pre-prompt decision across launches. This is app preference
/// state only; it is never sent to the backend.
abstract interface class NotificationPromptStore {
  /// Returns the saved decision, or null when the user has not decided yet.
  /// Throws when storage cannot be read, so callers can avoid re-prompting.
  Future<NotificationPromptDecision?> read();

  Future<void> write(NotificationPromptDecision decision);
}

/// Stores the decision as a tiny JSON file in the app-support directory.
class FileNotificationPromptStore implements NotificationPromptStore {
  FileNotificationPromptStore({required Future<Directory> Function() directory})
      : _directory = directory;

  static const _fileName = 'notification_prompt.json';

  final Future<Directory> Function() _directory;
  Future<void> _writeQueue = Future<void>.value();

  @override
  Future<NotificationPromptDecision?> read() async {
    final file = await _file();
    if (!await file.exists()) {
      return null;
    }
    try {
      final json = jsonDecode(await file.readAsString());
      final value = json is Map<String, Object?> ? json['decision'] : null;
      final decision = NotificationPromptDecision.values
          .where((decision) => decision.name == value)
          .firstOrNull;
      if (decision == null) {
        throw const FormatException('Unknown notification prompt decision.');
      }
      return decision;
    } on FormatException catch (error) {
      // Propagate corruption so the coordinator suppresses a repeat prompt.
      _debugLog('read_corrupt cause=$error');
      rethrow;
    }
  }

  @override
  Future<void> write(NotificationPromptDecision decision) {
    final operation = _writeQueue.then<void>((_) => _writeAtomically(decision));
    _writeQueue = operation.then<void>(
      (_) {},
      onError: (Object error, StackTrace stackTrace) {},
    );
    return operation;
  }

  Future<void> _writeAtomically(NotificationPromptDecision decision) async {
    final file = await _file();
    await file.parent.create(recursive: true);
    final temporary = File(
      '${file.path}.${DateTime.now().microsecondsSinceEpoch}.tmp',
    );
    await temporary.writeAsString(
      jsonEncode({
        'decision': decision.name,
        'updatedAt': DateTime.now().toUtc().toIso8601String(),
      }),
      flush: true,
    );
    await temporary.rename(file.path);
  }

  Future<File> _file() async => File('${(await _directory()).path}/$_fileName');

  void _debugLog(String message) {
    if (kDebugMode) {
      debugPrint('[FileNotificationPromptStore] $message');
    }
  }
}
