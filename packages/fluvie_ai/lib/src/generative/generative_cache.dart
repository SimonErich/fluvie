import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

/// The default on-disk cache root: `.fluvie/generative` under the working
/// directory, so produced assets live in the project and can be committed.
String defaultGenerativeCacheDir() => '${Directory.current.path}/.fluvie/generative';

/// A committable, content-addressed store for produced generative assets.
///
/// Each asset is written under `<root>/<provider>/<cacheKey>.<ext>` with a
/// `<cacheKey>.json` sidecar describing it (prompt, seed, params, mime, duration,
/// dimensions). Writes are atomic (temp file then rename) so a crashed render
/// never leaves a half-written asset the next run would treat as a cache hit.
final class GenerativeCache {
  /// Creates a cache rooted at [root].
  GenerativeCache(this.root);

  /// The cache root directory path.
  final String root;

  Directory _dir(String providerId) => Directory('$root/$providerId');

  /// The sidecar metadata file for [cacheKey] under [providerId].
  File sidecarFile(String providerId, String cacheKey) =>
      File('${_dir(providerId).path}/$cacheKey.json');

  /// The asset file for [cacheKey] under [providerId] with extension [ext].
  File assetFile(String providerId, String cacheKey, String ext) =>
      File('${_dir(providerId).path}/$cacheKey.$ext');

  /// Whether a sidecar (and thus a produced asset) exists for [cacheKey].
  bool has(String providerId, String cacheKey) => sidecarFile(providerId, cacheKey).existsSync();

  /// Reads and decodes the sidecar for [cacheKey].
  Map<String, Object?> readSidecar(String providerId, String cacheKey) =>
      jsonDecode(sidecarFile(providerId, cacheKey).readAsStringSync()) as Map<String, Object?>;

  /// Atomically writes [bytes] (as `<cacheKey>.<ext>`) and [sidecar] for
  /// [cacheKey] under [providerId].
  Future<void> write({
    required String providerId,
    required String cacheKey,
    required String ext,
    required Uint8List bytes,
    required Map<String, Object?> sidecar,
  }) async {
    await _dir(providerId).create(recursive: true);
    await _atomicBytes(assetFile(providerId, cacheKey, ext), bytes);
    await _atomicString(
      sidecarFile(providerId, cacheKey),
      const JsonEncoder.withIndent('  ').convert(sidecar),
    );
  }

  Future<void> _atomicBytes(File target, Uint8List bytes) async {
    final tmp = _tempFor(target);
    await tmp.writeAsBytes(bytes, flush: true);
    await tmp.rename(target.path);
  }

  Future<void> _atomicString(File target, String text) async {
    final tmp = _tempFor(target);
    await tmp.writeAsString(text, flush: true);
    await tmp.rename(target.path);
  }

  /// A unique sibling temp file (process id plus a counter), so two concurrent
  /// cold-start renders writing the same asset never clobber each other's
  /// partial write before the atomic rename swaps it into place.
  File _tempFor(File target) => File('${target.path}.$pid.${_tempSeq++}.tmp');
}

int _tempSeq = 0;
