import 'dart:convert';
import 'dart:io';

import 'package:fluvie_api/src/storage/download_grant.dart';
import 'package:fluvie_api/src/storage/file_store.dart';
import 'package:fluvie_api/src/storage/stored_object.dart';

/// A [FileStore] over a sandboxed filesystem directory.
///
/// Each object is a file under [root] at its key, beside a `<file>.meta.json`
/// sidecar holding the content type, visibility, and optional expiry (the
/// object's `createdAt` is the file's modification time). Writes are atomic
/// (a temp file is renamed into place). Keys are validated against
/// [isSafeStorageKey] so a request can never escape [root]. Every download is a
/// stream; the HTTP layer guards private files with a signed token.
final class LocalFileStore implements FileStore {
  /// Creates a store rooted at [root] (created on demand).
  LocalFileStore(this.root);

  /// The directory every object lives under.
  final Directory root;

  static const _metaSuffix = '.meta.json';

  @override
  Future<StoredObject> put(
    String key,
    Stream<List<int>> data, {
    required String contentType,
    required StoreVisibility visibility,
    int? length,
    DateTime? expiresAt,
  }) async {
    _checkKey(key);
    final file = _fileFor(key);
    await file.parent.create(recursive: true);
    final temp = File('${file.path}.tmp');
    final sink = temp.openWrite();
    try {
      await sink.addStream(data);
    } finally {
      await sink.close();
    }
    await temp.rename(file.path);
    await _metaFileFor(key).writeAsString(
      jsonEncode({
        'contentType': contentType,
        'visibility': visibility.name,
        if (expiresAt != null) 'expiresAtMs': expiresAt.toUtc().millisecondsSinceEpoch,
      }),
    );
    return (await stat(key))!;
  }

  @override
  Future<StoredObject?> stat(String key) async {
    _checkKey(key);
    final file = _fileFor(key);
    final meta = _metaFileFor(key);
    if (!file.existsSync() || !meta.existsSync()) return null;
    return _read(key, file, meta);
  }

  @override
  Future<Stream<List<int>>> openRead(String key) async {
    _checkKey(key);
    final file = _fileFor(key);
    if (!file.existsSync()) throw FileStoreException('No such object: $key');
    return file.openRead();
  }

  @override
  Future<void> delete(String key) async {
    _checkKey(key);
    final file = _fileFor(key);
    final meta = _metaFileFor(key);
    if (file.existsSync()) await file.delete();
    if (meta.existsSync()) await meta.delete();
  }

  @override
  Stream<StoredObject> list({String? prefix}) async* {
    if (!root.existsSync()) return;
    final entries = root
        .listSync(recursive: true)
        .whereType<File>()
        .where(
          (f) => f.path.endsWith(_metaSuffix),
        );
    for (final meta in entries) {
      final filePath = meta.path.substring(0, meta.path.length - _metaSuffix.length);
      final file = File(filePath);
      if (!file.existsSync()) continue;
      final key = _keyOf(file);
      if (prefix != null && !key.startsWith(prefix)) continue;
      yield _read(key, file, meta);
    }
  }

  @override
  Future<DownloadGrant> downloadGrant(
    String key, {
    required StoreVisibility visibility,
    required Duration ttl,
  }) async => const DownloadGrant.stream();

  StoredObject _read(String key, File file, File meta) {
    final json = jsonDecode(meta.readAsStringSync()) as Map<String, Object?>;
    final expiresMs = json['expiresAtMs'] as int?;
    return StoredObject(
      key: key,
      bytes: file.lengthSync(),
      contentType: json['contentType']! as String,
      createdAt: file.lastModifiedSync().toUtc(),
      visibility: StoreVisibility.values.byName(json['visibility']! as String),
      expiresAt: expiresMs == null
          ? null
          : DateTime.fromMillisecondsSinceEpoch(expiresMs, isUtc: true),
    );
  }

  void _checkKey(String key) {
    if (!isSafeStorageKey(key)) throw FileStoreException('Unsafe storage key: $key');
  }

  File _fileFor(String key) => File('${root.path}/$key');

  File _metaFileFor(String key) => File('${root.path}/$key$_metaSuffix');

  String _keyOf(File file) {
    final rootPath = root.absolute.path;
    final path = file.absolute.path;
    return path.substring(rootPath.length + 1).replaceAll(r'\', '/');
  }
}
