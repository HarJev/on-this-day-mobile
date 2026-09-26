import 'dart:io';

import 'atomic_json_file.dart';

/// Remembers the push token the backend last confirmed as registered, so a
/// later permission revocation can delete exactly that registration without
/// fetching a new token.
abstract interface class RegisteredTokenStore {
  /// Returns the confirmed token, or null when none is recorded.
  /// Throws when stored data is unreadable.
  Future<String?> read();

  /// Records [token] after the backend confirmed registration.
  Future<void> write(String token);

  /// Forgets the token after the backend confirmed deletion.
  Future<void> clear();
}

/// Stores the confirmed token in a JSON file in the app-support directory.
class FileRegisteredTokenStore implements RegisteredTokenStore {
  FileRegisteredTokenStore({required Future<Directory> Function() directory})
    : _file = AtomicJsonFile(
        directory: directory,
        fileName: 'registered_device_token.json',
      );

  final AtomicJsonFile _file;

  @override
  Future<String?> read() async {
    final json = await _file.read();
    if (json == null) {
      return null;
    }
    final token = json['token'];
    if (token is! String || token.isEmpty) {
      throw const FormatException('Stored device token is invalid.');
    }
    return token;
  }

  @override
  Future<void> write(String token) {
    if (token.isEmpty) {
      throw ArgumentError.value(token, 'token', 'must not be empty');
    }
    return _file.write({'token': token});
  }

  @override
  Future<void> clear() => _file.delete();
}
