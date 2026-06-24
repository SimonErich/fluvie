// coverage:ignore-file — thin JS bridge, exercised only by the manual
// clip-tagged browser harness; CI covers the web resolver against a fake.
import 'dart:js_interop';
import 'dart:js_interop_unsafe';
import 'dart:typed_data';

import 'package:fluvie/fluvie.dart';

/// Web factory: binds [WebClipDecoder] to the page-global `FluvieClipDecoder`
/// object (a WebCodecs `VideoDecoder` + demuxer wrapper exposing
/// `probe`/`extractFrames`) that the browser harness page installs before a
/// render. The heavy decoding lives in that JS bridge, the same way ffmpeg.wasm
/// lives behind `FluvieFfmpeg`; this Dart side only marshals bytes and indices.
WebClipDecoder createWebClipDecoder() => _WebClipDecoderBridge();

final class _WebClipDecoderBridge implements WebClipDecoder {
  JSObject get _bridge => globalContext.getProperty<JSObject>('FluvieClipDecoder'.toJS);

  @override
  Future<ClipMetadata> probe(Uint8List bytes) async {
    final result = await _bridge.callMethodVarArgs<JSPromise<JSObject>>('probe'.toJS, [
      bytes.toJS,
    ]).toDart;
    return (
      fps: result.getProperty<JSNumber>('fps'.toJS).toDartDouble,
      frameCount: result.getProperty<JSNumber>('frameCount'.toJS).toDartInt,
      width: result.getProperty<JSNumber>('width'.toJS).toDartInt,
      height: result.getProperty<JSNumber>('height'.toJS).toDartInt,
      // The WebCodecs decoder serves frames only; the in-browser render does not
      // mix a clip's embedded audio, so the track flag is always false here.
      hasAudio: false,
    );
  }

  @override
  Future<Map<int, RawFrame>> extractFrames(
    Uint8List bytes,
    List<int> sourceFrames, {
    required int width,
    required int height,
  }) async {
    final result = await _bridge.callMethodVarArgs<JSPromise<JSArray<JSUint8Array>>>(
      'extractFrames'.toJS,
      [
        bytes.toJS,
        [for (final i in sourceFrames) i.toJS].toJS,
        width.toJS,
        height.toJS,
      ],
    ).toDart;
    final buffers = result.toDart;
    return {
      for (var i = 0; i < sourceFrames.length; i++)
        sourceFrames[i]: RawFrame(
          frameIndex: sourceFrames[i],
          width: width,
          height: height,
          rgba: buffers[i].toDart,
        ),
    };
  }
}
