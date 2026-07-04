import 'dart:typed_data';

import 'package:flutter/services.dart' show AssetBundle, rootBundle;
import 'package:fluvie/fluvie.dart';
import 'package:http/http.dart' as http;

/// Loads a Fluvie audio `source` string into bytes for the in-browser encoder.
///
/// A Fluvie `Audio` source is an asset key, a file path, or a URL. The web
/// encoder writes those bytes into its in-memory sandbox, so a materializer just
/// returns them. The default [BundleWebAudioMaterializer] reads bundled assets
/// and fetches allowlisted network audio; tests inject a fake.
// ignore: one_member_abstracts — the seam stays mockable behind its provider.
abstract interface class WebAudioMaterializer {
  /// Resolves [source] to its bytes, fetching it if needed.
  Future<Uint8List> materialize(String source);
}

/// Fetches the bytes at a network [url].
typedef WebAudioFetch = Future<Uint8List> Function(Uri url);

/// The default [WebAudioMaterializer]: reads bundled assets through an
/// [AssetBundle] and fetches network audio (subject to a [NetworkAllowlist]).
///
/// A local file path throws a [FluvieRenderException]: the browser has no file
/// system, so bundle the audio as an asset or serve it over an allowlisted URL.
/// A network source without an [allowlist], or a host the allowlist rejects, also
/// throws. Network audio is subject to the browser's CORS rules, so the audio
/// host must allow the page's origin.
final class BundleWebAudioMaterializer implements WebAudioMaterializer {
  /// Creates a materializer over [bundle] (defaults to [rootBundle]), permitting
  /// network audio only from [allowlist] and fetching it through [fetch]
  /// (defaults to a browser HTTP GET).
  BundleWebAudioMaterializer({AssetBundle? bundle, this.allowlist, WebAudioFetch? fetch})
    : bundle = bundle ?? rootBundle,
      _fetch = fetch ?? _httpGet;

  /// The asset bundle bundled audio is read from.
  final AssetBundle bundle;

  /// The hosts network audio may be fetched from; `null` forbids network audio.
  final NetworkAllowlist? allowlist;

  final WebAudioFetch _fetch;

  @override
  Future<Uint8List> materialize(String source) async {
    if (source.startsWith('http://') || source.startsWith('https://')) {
      final list = allowlist;
      if (list == null) {
        throw FluvieRenderException(
          'Network audio ("$source") needs a NetworkAllowlist. Construct '
          'WebVideoRenderer with a WebAudioMaterializer that has one.',
        );
      }
      final url = Uri.parse(source);
      list.check(url);
      return _fetch(url);
    }
    if (source.startsWith('/')) {
      throw FluvieRenderException(
        'Local file audio ("$source") is not available in the browser (no file '
        'system). Bundle it as an asset or serve it over an allowlisted URL.',
      );
    }
    final data = await bundle.load(source);
    return data.buffer.asUint8List(data.offsetInBytes, data.lengthInBytes);
  }

  // coverage:ignore-line: real browser HTTP GET, exercised only in a browser; tests inject fetch.
  static Future<Uint8List> _httpGet(Uri url) => http.readBytes(url);
}
