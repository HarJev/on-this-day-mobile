import 'dart:convert';
import 'dart:io';

/// A small JSON object persisted in one file. Writes are serialized and
/// atomic (unique temporary file in the same directory, then rename), so a
/// crash never leaves a half-written file behind.
class AtomicJsonFile {
  AtomicJsonFile({
    required Future<Directory> Function() directory,
    required String fileName,
  }) : _directory = directory,
       _fileName = fileName;

  final Future<Directory> Function() _directory;
  final String _fileName;
  Future<void> _queue = Future<void>.value();
  int _sequence = 0;

  /// Returns the stored object, or null when the file does not exist.
  /// Throws [FormatException] when the content is not a JSON object.
  Future<Map<String, Object?>?> read() async {
    final file = await _file();
    if (!await file.exists()) {
      return null;
    }
    final decoded = jsonDecode(await file.readAsString());
    if (decoded is! Map<String, Object?>) {
      throw const FormatException('Expected a JSON object.');
    }
    return decoded;
  }

  Future<void> write(Map<String, Object?> value) =>
      _serialize(() => _writeAtomically(value));

  Future<void> delete() => _serialize(() async {
    final file = await _file();
    if (await file.exists()) {
      await file.delete();
    }
  });

  Future<void> _serialize(Future<void> Function() operation) {
    final next = _queue.then<void>((_) => operation());
    _queue = next.then<void>((_) {}, onError: (Object _, StackTrace _) {});
    return next;
  }

  Future<void> _writeAtomically(Map<String, Object?> value) async {
    final file = await _file();
    await file.parent.create(recursive: true);
    final temporary = File(
      '${file.path}.${DateTime.now().microsecondsSinceEpoch}.${_sequence++}.tmp',
    );
    try {
      await temporary.writeAsString(jsonEncode(value), flush: true);
      await temporary.rename(file.path);
    } catch (_) {
      if (await temporary.exists()) {
        await temporary.delete();
      }
      rethrow;
    }
  }

  Future<File> _file() async => File('${(await _directory()).path}/$_fileName');
}
