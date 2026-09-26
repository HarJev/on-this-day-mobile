import 'dart:async';
import 'dart:convert';
import 'dart:developer' as developer;
import 'dart:io';
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:crypto/crypto.dart';
import 'package:path/path.dart' as path;

import 'image_request_cancellation.dart';

typedef DecodeEncodedImage =
    Future<ui.Image> Function(
      Uint8List bytes,
      ImageRequestCancellation cancellation, {
      required int maxEdge,
      required void Function(int) reserveDecodedBytes,
    });

typedef FetchEncodedImage =
    Future<Uint8List> Function(ImageRequestCancellation cancellation);

/// A disposable on-device cache of verified encoded image bytes.
final class EncodedImageCache {
  EncodedImageCache({
    required Future<Directory> Function() cacheDirectory,
    this.maxBytes = 64 * 1024 * 1024,
    this.maxEntryBytes = 8 * 1024 * 1024,
    void Function(String message)? diagnostic,
  }) : _cacheDirectory = cacheDirectory,
       _diagnostic = diagnostic ?? _defaultDiagnostic {
    if (maxBytes <= 0 || maxEntryBytes <= 0 || maxEntryBytes > maxBytes) {
      throw ArgumentError('Cache limits must be positive and compatible');
    }
  }

  final Future<Directory> Function() _cacheDirectory;
  final int maxBytes;
  final int maxEntryBytes;
  final void Function(String message) _diagnostic;

  Future<_CacheIndex>? _indexFuture;
  final _loads = <String, _SharedImageLoad>{};
  Future<void> _indexWork = Future<void>.value();

  /// Returns an owned image handle. The cache itself retains encoded bytes only.
  Future<ui.Image> load(
    Uri url,
    ImageRequestCancellation caller, {
    required int maxBytes,
    required int maxEdge,
    required FetchEncodedImage download,
    required DecodeEncodedImage decode,
    required void Function(int) reserveEncodedBytes,
    required void Function(int) reserveDecodedBytes,
  }) async {
    caller.check();
    if (url.scheme != 'https' || maxBytes <= 0 || maxBytes > maxEntryBytes) {
      throw const ImageCacheException(ImageCacheFailure.invalidRequest);
    }
    final key = _keyFor(url);
    var load = _loads[key];
    if (load == null || load.cancellation.isCancelled) {
      load = _SharedImageLoad(ImageRequestCancellation());
      _loads[key] = load;
      load.result = _load(
        key,
        url,
        load.cancellation,
        maxBytes: maxBytes,
        maxEdge: maxEdge,
        download: download,
        decode: decode,
      );
      unawaited(
        load.result!.then<void>(
          (_) => load!.completed = true,
          onError: (_, _) => load!.completed = true,
        ),
      );
    }
    load.waiters++;
    try {
      final entry = await caller.wait(load.result!);
      caller.check();
      reserveEncodedBytes(entry.bytes.length);
      reserveDecodedBytes(entry.image.width * entry.image.height * 4);
      caller.check();
      return entry.image.clone();
    } finally {
      _release(key, load);
    }
  }

  Future<void> invalidate(Uri url) => _withIndexLock(() async {
    final index = await _index();
    await _removeEntry(index, _keyFor(url));
  });

  String _keyFor(Uri url) =>
      sha256.convert(utf8.encode('on-this-day:image-cache:v1|$url')).toString();

  Future<_ValidatedImage> _load(
    String key,
    Uri url,
    ImageRequestCancellation cancellation, {
    required int maxBytes,
    required int maxEdge,
    required FetchEncodedImage download,
    required DecodeEncodedImage decode,
  }) async {
    try {
      final index = await _index();
      final cached = await _readEntry(index, key, maxBytes);
      if (cached != null) {
        try {
          final image = await _decode(cached, cancellation, decode, maxEdge);
          await _touch(key);
          return _ValidatedImage(cached, image);
        } on ImageRequestCancelledException {
          rethrow;
        } catch (_) {
          await invalidate(url);
          _diagnostic('image_cache outcome=corrupt key=$key source=cache');
        }
      }

      cancellation.check();
      final downloaded = await download(cancellation);
      cancellation.check();
      if (downloaded.length > maxBytes || downloaded.length > maxEntryBytes) {
        throw const ImageCacheException(ImageCacheFailure.encodedLimit);
      }
      final image = await _decode(downloaded, cancellation, decode, maxEdge);
      try {
        await _publish(index, key, downloaded);
      } on FileSystemException {
        _diagnostic('image_cache outcome=write_failed key=$key');
      }
      return _ValidatedImage(downloaded, image);
    } finally {
      final current = _loads[key];
      if (current?.cancellation == cancellation && current!.waiters == 0) {
        _loads.remove(key);
      }
    }
  }

  Future<ui.Image> _decode(
    Uint8List bytes,
    ImageRequestCancellation cancellation,
    DecodeEncodedImage decode,
    int maxEdge,
  ) async {
    try {
      final image = await decode(
        bytes,
        cancellation,
        maxEdge: maxEdge,
        reserveDecodedBytes: (_) {},
      );
      cancellation.check();
      return image;
    } on ImageCacheException {
      rethrow;
    } catch (error) {
      throw ImageCacheException(ImageCacheFailure.decoding, cause: error);
    }
  }

  void _release(String key, _SharedImageLoad load) {
    load.waiters--;
    if (load.waiters != 0) return;
    if (!load.completed) {
      load.cancellation.cancel();
      if (identical(_loads[key], load)) _loads.remove(key);
      return;
    }
    unawaited(
      load.result!.then((entry) => entry.image.dispose(), onError: (_, _) {}),
    );
    if (identical(_loads[key], load)) _loads.remove(key);
  }

  Future<_CacheIndex> _index() => _indexFuture ??= _openIndex();

  Future<_CacheIndex> _openIndex() async {
    final directory = await _cacheDirectory();
    await directory.create(recursive: true);
    final indexFile = File(path.join(directory.path, 'index.json'));
    try {
      final decoded = jsonDecode(await indexFile.readAsString()) as Object?;
      final index = _CacheIndex.fromJson(directory, decoded);
      await _reclaimOrphans(index);
      return index;
    } catch (_) {
      final index = await _rebuildIndex(directory);
      await _writeIndex(index);
      return index;
    }
  }

  Future<_CacheIndex> _rebuildIndex(Directory directory) async {
    final entries = <String, _CacheMetadata>{};
    await for (final entity in directory.list(followLinks: false)) {
      if (entity is! File || !entity.path.endsWith('.bin')) continue;
      final key = path.basenameWithoutExtension(entity.path);
      final bytes = await entity.readAsBytes();
      if (!_validKey(key) || bytes.isEmpty || bytes.length > maxEntryBytes) {
        await entity.delete();
        continue;
      }
      final stat = await entity.stat();
      entries[key] = _CacheMetadata(
        bytes.length,
        sha256.convert(bytes).toString(),
        stat.modified.millisecondsSinceEpoch,
      );
    }
    final index = _CacheIndex(directory, entries);
    await _evict(index);
    return index;
  }

  Future<Uint8List?> _readEntry(
    _CacheIndex index,
    String key,
    int callerMaxBytes,
  ) async {
    final metadata = index.entries[key];
    if (metadata == null || metadata.length > callerMaxBytes) return null;
    final file = File(path.join(index.directory.path, '$key.bin'));
    try {
      final bytes = await file.readAsBytes();
      if (bytes.length != metadata.length ||
          sha256.convert(bytes).toString() != metadata.checksum) {
        await _withIndexLock(() => _removeEntry(index, key));
        return null;
      }
      return bytes;
    } on FileSystemException {
      await _withIndexLock(() => _removeEntry(index, key));
      return null;
    }
  }

  Future<void> _publish(_CacheIndex index, String key, Uint8List bytes) =>
      _withIndexLock(() async {
        final target = File(path.join(index.directory.path, '$key.bin'));
        final temporary = File(
          path.join(
            index.directory.path,
            '.$key.${DateTime.now().microsecondsSinceEpoch}.tmp',
          ),
        );
        await temporary.writeAsBytes(bytes, flush: true);
        await temporary.rename(target.path);
        index.entries[key] = _CacheMetadata(
          bytes.length,
          sha256.convert(bytes).toString(),
          DateTime.now().millisecondsSinceEpoch,
        );
        await _evict(index);
        await _writeIndex(index);
      });

  Future<void> _touch(String key) => _withIndexLock(() async {
    final index = await _index();
    final metadata = index.entries[key];
    if (metadata == null) return;
    index.entries[key] = metadata.copyWith(
      lastAccessMs: DateTime.now().millisecondsSinceEpoch,
    );
    await _writeIndex(index);
  });

  Future<void> _reclaimOrphans(_CacheIndex index) async {
    await for (final entity in index.directory.list(followLinks: false)) {
      if (entity is! File) continue;
      final name = path.basename(entity.path);
      if (name == 'index.json') continue;
      if (name.endsWith('.tmp') ||
          (name.endsWith('.bin') &&
              !index.entries.containsKey(
                path.basenameWithoutExtension(name),
              ))) {
        await entity.delete();
      }
    }
  }

  Future<void> _evict(_CacheIndex index) async {
    var total = index.entries.values.fold<int>(
      0,
      (sum, metadata) => sum + metadata.length,
    );
    final oldest = index.entries.entries.toList()
      ..sort((left, right) {
        final access = left.value.lastAccessMs.compareTo(
          right.value.lastAccessMs,
        );
        return access != 0 ? access : left.key.compareTo(right.key);
      });
    for (final entry in oldest) {
      if (total <= maxBytes) return;
      final file = File(path.join(index.directory.path, '${entry.key}.bin'));
      try {
        await file.delete();
      } on FileSystemException {
        // Disposable cache entries can be retried during later maintenance.
      }
      index.entries.remove(entry.key);
      total -= entry.value.length;
    }
  }

  Future<void> _removeEntry(_CacheIndex index, String key) async {
    final file = File(path.join(index.directory.path, '$key.bin'));
    try {
      await file.delete();
    } on FileSystemException {
      // A missing cache file is a regular cache miss.
    }
    index.entries.remove(key);
    await _writeIndex(index);
  }

  Future<void> _writeIndex(_CacheIndex index) async {
    final target = File(path.join(index.directory.path, 'index.json'));
    final temporary = File(
      path.join(
        index.directory.path,
        '.index.${DateTime.now().microsecondsSinceEpoch}.tmp',
      ),
    );
    await temporary.writeAsString(jsonEncode(index.toJson()), flush: true);
    await temporary.rename(target.path);
  }

  Future<T> _withIndexLock<T>(Future<T> Function() action) {
    final next = _indexWork.then((_) => action());
    _indexWork = next.then<void>((_) {}, onError: (_, _) {});
    return next;
  }

  bool _validKey(String value) => RegExp(r'^[a-f0-9]{64}$').hasMatch(value);

  static void _defaultDiagnostic(String message) {
    developer.log(message, name: 'on_this_day.image_cache');
  }
}

final class ImageCacheException implements Exception {
  const ImageCacheException(this.kind, {this.cause});

  final ImageCacheFailure kind;
  final Object? cause;
}

enum ImageCacheFailure { invalidRequest, encodedLimit, decoding }

final class _SharedImageLoad {
  _SharedImageLoad(this.cancellation);

  final ImageRequestCancellation cancellation;
  Future<_ValidatedImage>? result;
  var waiters = 0;
  var completed = false;
}

final class _ValidatedImage {
  const _ValidatedImage(this.bytes, this.image);

  final Uint8List bytes;
  final ui.Image image;
}

final class _CacheIndex {
  _CacheIndex(this.directory, this.entries);

  final Directory directory;
  final Map<String, _CacheMetadata> entries;

  factory _CacheIndex.fromJson(Directory directory, Object? value) {
    if (value is! Map<String, Object?> || value['version'] != 1) {
      throw const FormatException('Invalid image cache index');
    }
    final rawEntries = value['entries'];
    if (rawEntries is! Map<String, Object?>) {
      throw const FormatException('Invalid image cache entries');
    }
    final entries = <String, _CacheMetadata>{};
    for (final entry in rawEntries.entries) {
      final rawMetadata = entry.value;
      if (rawMetadata is! Map<String, Object?> ||
          !RegExp(r'^[a-f0-9]{64}$').hasMatch(entry.key)) {
        throw const FormatException('Invalid image cache entry');
      }
      entries[entry.key] = _CacheMetadata.fromJson(rawMetadata);
    }
    return _CacheIndex(directory, entries);
  }

  Map<String, Object?> toJson() => {
    'version': 1,
    'entries': {
      for (final entry in entries.entries) entry.key: entry.value.toJson(),
    },
  };
}

final class _CacheMetadata {
  const _CacheMetadata(this.length, this.checksum, this.lastAccessMs);

  final int length;
  final String checksum;
  final int lastAccessMs;

  factory _CacheMetadata.fromJson(Map<String, Object?> value) {
    final length = value['length'];
    final checksum = value['checksum'];
    final lastAccessMs = value['lastAccessMs'];
    if (length is! int ||
        length <= 0 ||
        checksum is! String ||
        !RegExp(r'^[a-f0-9]{64}$').hasMatch(checksum) ||
        lastAccessMs is! int) {
      throw const FormatException('Invalid image cache metadata');
    }
    return _CacheMetadata(length, checksum, lastAccessMs);
  }

  _CacheMetadata copyWith({int? lastAccessMs}) =>
      _CacheMetadata(length, checksum, lastAccessMs ?? this.lastAccessMs);

  Map<String, Object?> toJson() => {
    'length': length,
    'checksum': checksum,
    'lastAccessMs': lastAccessMs,
  };
}
