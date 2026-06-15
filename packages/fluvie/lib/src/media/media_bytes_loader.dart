import 'dart:io';
import 'dart:typed_data';

import 'package:flutter/services.dart' show AssetBundle, rootBundle;
import 'package:fluvie/src/core/errors/fluvie_render_exception.dart';
import 'package:fluvie/src/core/media/media_source.dart';
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
  /// [readFile] (defaults to `File.readAsBytes`).
  ///
  /// [readFile] is injectable so a test can drive a throwing fake and exercise
  /// the typed failure wrap without depending on filesystem permissions.
  MediaBytesLoader({
    required this.httpClient,
    required this.allowlist,
    AssetBundle? bundle,
    Future<Uint8List> Function(String path)? readFile,
  }) : bundle = bundle ?? rootBundle,
       _readFile = readFile ?? _readBytes;

  /// The bundle asset sources are read from.
  final AssetBundle bundle;

  /// The network seam network sources are fetched through.
  final MediaHttpClient httpClient;

  /// The safety gate every network URL is checked against before a fetch.
  final NetworkAllowlist allowlist;

  // The injectable file-read seam (see the [readFile] constructor argument).
  final Future<Uint8List> Function(String path) _readFile;

  static Future<Uint8List> _readBytes(String path) => File(path).readAsBytes();

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
    final file = File(path);
    if (!file.existsSync()) {
      throw FluvieRenderException('Media file "$path" does not exist.');
    }
    try {
      return await _readFile(path);
    } on Object catch (error) {
      throw FluvieRenderException('Failed to read media file "$path": $error.');
    }
  }

  Future<Uint8List> _loadNetwork(Uri url) {
    allowlist.check(url);
    return httpClient.get(url);
  }
}
