import 'dart:io';

import 'atomic_json_file.dart';

/// What the user has answered to the in-app notification pre-prompt.
final class NotificationPromptRecord {
  const NotificationPromptRecord({
    this.requested = false,
    this.declineCount = 0,
    this.declinedAt,
  }) : assert(declineCount >= 0);

  /// The user chose "Turn on notifications" and the system request completed.
  /// This is permanent.
  final bool requested;

  /// How many times the user chose "Not now".
  final int declineCount;

  /// When the most recent "Not now" happened (UTC).
  final DateTime? declinedAt;

  NotificationPromptRecord declinedOn(DateTime now) => NotificationPromptRecord(
    requested: requested,
    declineCount: declineCount + 1,
    declinedAt: now.toUtc(),
  );

  NotificationPromptRecord get withRequest => NotificationPromptRecord(
    requested: true,
    declineCount: declineCount,
    declinedAt: declinedAt,
  );

  @override
  bool operator ==(Object other) =>
      other is NotificationPromptRecord &&
      other.requested == requested &&
      other.declineCount == declineCount &&
      other.declinedAt == declinedAt;

  @override
  int get hashCode => Object.hash(requested, declineCount, declinedAt);

  @override
  String toString() =>
      'NotificationPromptRecord(requested: $requested, '
      'declineCount: $declineCount, declinedAt: $declinedAt)';
}

/// Remembers the pre-prompt answers across launches. This is app preference
/// state only; it is never sent to the backend.
abstract interface class NotificationPromptStore {
  /// Returns the saved record, or null when the user has never answered.
  /// Throws when stored data is unreadable or unrecognized, so callers can
  /// fail closed rather than prompt again.
  Future<NotificationPromptRecord?> read();

  Future<void> write(NotificationPromptRecord record);
}

/// Stores the record as a small JSON file in the app-support directory.
///
/// Current format: `{"version": 2, "requested": bool, "declineCount": int,
/// "declinedAt": ISO-8601 | null}`. The first release wrote
/// `{"decision": "declined" | "requested", "updatedAt": ISO-8601}`; it is read
/// as one decline at `updatedAt`, or as a completed request.
class FileNotificationPromptStore implements NotificationPromptStore {
  FileNotificationPromptStore({required Future<Directory> Function() directory})
    : _file = AtomicJsonFile(
        directory: directory,
        fileName: 'notification_prompt.json',
      );

  static const _version = 2;

  final AtomicJsonFile _file;

  @override
  Future<NotificationPromptRecord?> read() async {
    final json = await _file.read();
    if (json == null) {
      return null;
    }
    if (json.containsKey('version')) {
      return _readCurrent(json);
    }
    return _readLegacy(json);
  }

  @override
  Future<void> write(NotificationPromptRecord record) => _file.write({
    'version': _version,
    'requested': record.requested,
    'declineCount': record.declineCount,
    'declinedAt': record.declinedAt?.toUtc().toIso8601String(),
  });

  static NotificationPromptRecord _readCurrent(Map<String, Object?> json) {
    final version = json['version'];
    final requested = json['requested'];
    final declineCount = json['declineCount'];
    final declinedAtValue = json['declinedAt'];
    if (version != _version ||
        requested is! bool ||
        declineCount is! int ||
        declineCount < 0 ||
        (declinedAtValue != null && declinedAtValue is! String)) {
      throw const FormatException('Unrecognized notification prompt record.');
    }
    final declinedAt = declinedAtValue == null
        ? null
        : _parseTime(declinedAtValue as String);
    if (declineCount > 0 && declinedAt == null) {
      throw const FormatException('Decline recorded without a time.');
    }
    return NotificationPromptRecord(
      requested: requested,
      declineCount: declineCount,
      declinedAt: declinedAt,
    );
  }

  static NotificationPromptRecord _readLegacy(Map<String, Object?> json) {
    final updatedAt = json['updatedAt'];
    return switch (json['decision']) {
      'requested' => const NotificationPromptRecord(requested: true),
      'declined' when updatedAt is String => NotificationPromptRecord(
        declineCount: 1,
        declinedAt: _parseTime(updatedAt),
      ),
      _ => throw const FormatException(
        'Unrecognized legacy notification prompt data.',
      ),
    };
  }

  static DateTime _parseTime(String value) {
    final parsed = DateTime.tryParse(value);
    if (parsed == null) {
      throw FormatException('Invalid notification prompt time.', value);
    }
    return parsed.toUtc();
  }
}
