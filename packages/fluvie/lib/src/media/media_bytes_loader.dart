import 'dart:typed_data';

import 'package:flutter/services.dart' show AssetBundle, rootBundle;
import 'package:fluvie/src/core/errors/fluvie_render_exception.dart';
import 'package:fluvie/src/core/media/media_source.dart';
import 'package:fluvie/src/media/io/file_bytes.dart';
import 'package:fluvie/src/media/net/media_http_client.dart';
import 'package:fluvie/src/media/net/network_allowlist.dart';

/// Loads the raw bytes for one [MediaSource], per kind, over injected seams.
///
/// This is the IO layer the `MediaRepository` sits on: it switches on the
/// source variant and reads bytes from the right place — the asset [bundle],
/// the file system, the allowlisted [httpClient], or verbatim memory. Every
/// failure is a typed [FluvieRenderException] that names the source, and the
/// network path always consults the [allowlist] before any fetch.
final class MediaBytesLoader {
  /// Creates a loader over the asset [bundle] (defaults to `rootBundle`), the
  /// [httpClient], the network [allowlist], and an optional file-read seam
  /// [readFile] (defaults to the platform `readFileBytes`).
  ///
  /// [readFile] is injectable so a test can drive a throwing fake and exercise
  /// the typed failure wrap without depending on filesystem permissions.
  MediaBytesLoader({
    required this.httpClient,
    required this.allowlist,
    AssetBundle? bundle,
    Future<Uint8List> Function(String path)? readFile,
    this.blockFileSources = false,
  }) : bundle = bundle ?? rootBundle,
       _readFile = readFile ?? readFileBytes;

  /// The bundle asset sources are read from.
  final AssetBundle bundle;

  /// The network seam network sources are fetched through.
  final MediaHttpClient httpClient;

  /// The safety gate every network URL is checked against before a fetch.
  final NetworkAllowlist allowlist;

  /// Whether a [FileSource] is rejected outright instead of read.
  ///
  /// Set this on the untrusted render path (a server rendering a submitted
  /// spec or snippet): those inputs have no legitimate local-path need, so a
  /// `FileSource` is treated as an attempt to read the host's filesystem.
  final bool blockFileSources;

  // The injectable file-read seam (see the [readFile] constructor argument).
  final Future<Uint8List> Function(String path) _readFile;

  /// Reads the bytes for [source]; throws a [FluvieRenderException] on any
  /// failure.
  Future<Uint8List> load(MediaSource source) => switch (source) {
    AssetSource(:final name) => _loadAsset(name),
    FileSource(:final path) => _loadFile(path),
    NetworkSource(:final url) => _loadNetwork(url),
    MemorySource(:final bytes) => Future.value(bytes),
  };

  Future<Uint8List> _loadAsset(String name) async {
    try {
      final data = await bundle.load(name);
      return data.buffer.asUint8List(data.offsetInBytes, data.lengthInBytes);
    } on Object catch (error) {
      throw FluvieRenderException('Failed to load asset "$name": $error.');
    }
  }

  Future<Uint8List> _loadFile(String path) async {
    if (blockFileSources) {
      throw FluvieRenderException(
        'A FileSource is not allowed here: reading local files is disabled on '
        'this render path (path "$path").',
      );
    }
    try {
      return await _readFile(path);
    } on FluvieRenderException {
      rethrow;
    } on Object catch (error) {
      throw FluvieRenderException('Failed to read media file "$path": $error.');
    }
  }

  Future<Uint8List> _loadNetwork(Uri url) {
    allowlist.check(url);
    return httpClient.get(url);
  }
}
