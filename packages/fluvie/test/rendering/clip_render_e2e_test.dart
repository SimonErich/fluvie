// Task 26: the end-to-end clip path on the Dart side. A Video with a Clip
// renders through renderToSandbox over a WebImageMediaResolver wired with a fake
// WebClipDecoder. This exercises the whole chain — preResolveAll loads the clip
// bytes, preResolveCompositionClips probes and extracts the planned frames, the
// ClipPainter reads each decoded frame synchronously per composition frame — so
// a successful render proves the pre-pass extracted exactly the frames the
// painter needs (a missing one would throw). The live WebCodecs decode is
// covered by the manual browser harness; here the decoder is a fake.

import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:fluvie/fluvie.dart';
import 'package:fluvie/rendering.dart';
import 'package:fluvie/src/media/media_bytes_loader.dart';
import 'package:fluvie/src/media/net/media_http_client.dart';
import 'package:fluvie/src/media/web_image_media_resolver.dart';

class _MapBundle extends CachingAssetBundle {
  _MapBundle(this._data);
  final Map<String, Uint8List> _data;
  @override
  Future<ByteData> load(String key) async {
    final bytes = _data[key];
    if (bytes == null) throw FluvieRenderException('asset not found: $key');
    return ByteData.view(bytes.buffer);
  }
}

class _NoHttp implements MediaHttpClient {
  @override
  Future<Uint8List> get(Uri url) async => throw FluvieRenderException('no network: $url');
}

/// A decoder that serves opaque-white 32x32 frames, so a painted clip leaves a
/// `0xFF,0xFF,0xFF,0xFF` pixel in the capture.
class _WhiteClipDecoder implements WebClipDecoder {
  @override
  Future<ClipMetadata> probe(Uint8List bytes) async =>
      (fps: 30.0, frameCount: 30, width: 32, height: 32, hasAudio: false);

  @override
  Future<Map<int, RawFrame>> extractFrames(
    Uint8List bytes,
    List<int> sourceFrames, {
    required int width,
    required int height,
  }) async => {
    for (final i in sourceFrames)
      i: RawFrame(
        frameIndex: i,
        width: width,
        height: height,
        rgba: Uint8List(width * height * 4)..fillRange(0, width * height * 4, 0xFF),
      ),
  };
}

void main() {
  testWidgets('renders a Video with a Clip end to end through the web resolver', (tester) async {
    tester.view
      ..physicalSize = const Size(32, 32)
      ..devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    final resolver = WebImageMediaResolver(
      loader: MediaBytesLoader(
        bundle: _MapBundle({'clip.mp4': Uint8List(16)}),
        httpClient: _NoHttp(),
        allowlist: NetworkAllowlist.allowAny(),
      ),
      clipDecoder: _WhiteClipDecoder(),
    );
    final video = Video(
      width: 32,
      height: 32,
      scenes: [
        Scene(duration: const Time.frames(3), children: [Clip.asset('clip.mp4')]),
      ],
    );
    final sandbox = MemoryRenderSandbox();

    await tester.runAsync(() async {
      await renderToSandbox(
        composition: video,
        aspect: Aspect.square,
        frameCount: 3,
        sandbox: sandbox,
        capture: const RepaintBoundaryCaptureService(),
        pumpWidget: tester.pumpWidget,
        pumpFrame: tester.pump,
        longEdge: 32,
        resolver: resolver,
      );
    });

    final frames = await sandbox.readBytes('frames.rgba');
    expect(frames.length, 3 * 32 * 32 * 4, reason: 'three 32x32 RGBA frames captured');
    expect(_hasWhitePixel(frames), isTrue, reason: 'the clip painted its decoded frame');
  });
}

/// True when [frames] contains an opaque-white pixel, the clip's painted marker.
bool _hasWhitePixel(Uint8List frames) {
  for (var i = 0; i + 4 <= frames.length; i += 4) {
    if (frames[i] == 0xFF &&
        frames[i + 1] == 0xFF &&
        frames[i + 2] == 0xFF &&
        frames[i + 3] == 0xFF) {
      return true;
    }
  }
  return false;
}
