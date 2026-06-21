import 'dart:io';
import 'dart:typed_data';

import 'package:fluvie/fluvie.dart';
import 'package:fluvie_mobile_encoder/src/mobile_audio_materializer.dart';
import 'package:http/http.dart' as http;

/// Fetches the bytes at a network [url].
typedef MobileAudioFetch = Future<Uint8List> Function(Uri url);

/// A [MobileAudioMaterializer] that fetches allowlisted network audio to a local
/// file the native encoder can read, delegating asset and file sources to an
/// inner materializer.
///
/// Network audio is opt-in by construction: build the renderer with this
/// materializer and a [NetworkAllowlist] of permitted hosts
/// (`OnDeviceVideoRenderer(audioMaterializer: NetworkAudioMaterializer(allowlist: ...))`).
/// A URL the allowlist rejects throws a [FluvieRenderException] before any fetch;
/// asset keys and file paths pass to [delegate] (a [BundleAudioMaterializer] by
/// default). The fetched bytes are written under [cacheDir] (a fresh temp dir
/// when omitted) and the local path is returned, so the native side is unchanged.
final class NetworkAudioMaterializer implements MobileAudioMaterializer {
  /// Creates a network materializer permitting only [allowlist] hosts, fetching
  /// through [fetch] (a real HTTP GET by default) and delegating non-network
  /// sources to [delegate] (a [BundleAudioMaterializer] by default).
  NetworkAudioMaterializer({
    required this.allowlist,
    MobileAudioMaterializer? delegate,
    MobileAudioFetch? fetch,
    this.cacheDir,
  }) : delegate = delegate ?? BundleAudioMaterializer(),
       _fetch = fetch ?? _httpGet;

  /// The hosts network audio may be fetched from.
  final NetworkAllowlist allowlist;

  /// Handles asset and file sources (and is the fallback for everything not http).
  final MobileAudioMaterializer delegate;

  /// Where fetched audio is written; `null` uses a fresh temp directory.
  final Directory? cacheDir;

  final MobileAudioFetch _fetch;

  @override
  Future<String> materialize(String source) async {
    if (source.startsWith('http://') || source.startsWith('https://')) {
      final url = Uri.parse(source);
      allowlist.check(url);
      final bytes = await _fetch(url);
      final dir = cacheDir ?? await Directory.systemTemp.createTemp('fluvie_mobile_net_audio_');
      final file = File('${dir.path}/${_safeName(source)}');
      await file.writeAsBytes(bytes);
      return file.path;
    }
    return delegate.materialize(source);
  }

  static String _safeName(String source) => source.replaceAll(RegExp('[^A-Za-z0-9._-]'), '_');

  // coverage:ignore-line: real network GET, exercised on-device only; tests inject fetch.
  static Future<Uint8List> _httpGet(Uri url) => http.readBytes(url);
}
