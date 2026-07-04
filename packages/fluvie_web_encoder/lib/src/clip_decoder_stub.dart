import 'dart:typed_data';

import 'package:fluvie/rendering.dart';

/// The non-browser fallback: a [WebClipDecoder] that fails on use, so the symbol
/// is importable on the VM (tests, analysis) while real decoding stays
/// browser-only. The real bridge ships in `clip_decoder_web.dart`.
WebClipDecoder createWebClipDecoder() => const _UnavailableWebClipDecoder();

final class _UnavailableWebClipDecoder implements WebClipDecoder {
  const _UnavailableWebClipDecoder();

  Never _unavailable() => throw UnsupportedError(
    'In-browser clip decoding needs a browser with WebCodecs; it is not '
    'available on this platform. Render clips on the desktop or server path.',
  );

  @override
  Future<ClipMetadata> probe(Uint8List bytes) async => _unavailable();

  @override
  Future<Map<int, RawFrame>> extractFrames(
    Uint8List bytes,
    List<int> sourceFrames, {
    required int width,
    required int height,
  }) async => _unavailable();
}
