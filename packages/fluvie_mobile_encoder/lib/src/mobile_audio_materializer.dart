import 'dart:io';

import 'package:flutter/services.dart';
import 'package:fluvie_mobile_encoder/src/fluvie_mobile_encoder_exception.dart';

/// Turns a Fluvie audio `source` string into a local file the native encoder can
/// read.
///
/// A Fluvie `Audio` source is an asset key, a file path, or a URL. On a device
/// the native mixer needs a real local file, so an implementation resolves each
/// source to one. The default [BundleAudioMaterializer] reads bundled assets and
/// passes local file paths through; tests inject a fake.
// A single-method seam by design: it stays mockable behind its provider.
// ignore: one_member_abstracts
abstract interface class MobileAudioMaterializer {
  /// Resolves [source] to a local file path, fetching it if needed.
  Future<String> materialize(String source);
}

/// The default [MobileAudioMaterializer]: reads bundled assets through an
/// [AssetBundle] and passes absolute file paths straight through.
///
/// A network URL throws a [FluvieMobileEncoderException]: this release does not
/// fetch remote audio on-device, so bundle it as an asset or pre-download it to a
/// file. Materialized assets are written under a cache directory (a fresh temp
/// dir by default), named from a sanitized form of the asset key.
final class BundleAudioMaterializer implements MobileAudioMaterializer {
  /// Creates a materializer over [bundle] (defaults to [rootBundle]), writing
  /// materialized assets into [cacheDir] (a fresh temp dir when omitted).
  BundleAudioMaterializer({AssetBundle? bundle, this.cacheDir}) : bundle = bundle ?? rootBundle;

  /// The asset bundle that bundled audio is read from.
  final AssetBundle bundle;

  /// Where materialized assets are written; `null` uses a fresh temp directory.
  final Directory? cacheDir;

  @override
  Future<String> materialize(String source) async {
    if (source.startsWith('http://') || source.startsWith('https://')) {
      throw FluvieMobileEncoderException(
        'Network audio ("$source") is not supported on-device yet. Bundle it as '
        'an asset or pass a local file path.',
        code: 'unsupported_audio_source',
      );
    }
    if (source.startsWith('/')) return source;
    final data = await bundle.load(source);
    final dir = cacheDir ?? await Directory.systemTemp.createTemp('fluvie_mobile_audio_');
    final file = File('${dir.path}/${_safeName(source)}');
    await file.writeAsBytes(data.buffer.asUint8List(data.offsetInBytes, data.lengthInBytes));
    return file.path;
  }

  static String _safeName(String source) => source.replaceAll(RegExp('[^A-Za-z0-9._-]'), '_');
}
