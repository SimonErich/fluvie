// The preview clip path end to end on the Dart side: PreviewMediaScope over a
// real WebImageMediaResolver (fake WebClipDecoder, no live WebCodecs) drives the
// same chain a render drives — preResolveAll loads the bytes,
// preResolveCompositionClips probes and extracts the planned frames, and the
// ClipPainter reads each decoded frame synchronously. A painted RawImage proves
// preview reuses the capture path rather than a second decode path, and the
// decoder's recorded size proves the proxy bound reaches the actual decode.

import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart' hide Animation, Clip, Image, Tween;
import 'package:flutter/widgets.dart' as flutter;
import 'package:flutter_test/flutter_test.dart';
import 'package:fluvie/fluvie.dart';
import 'package:fluvie/rendering.dart';
import 'package:fluvie/src/media/media_bytes_loader.dart';
import 'package:fluvie/src/media/net/media_http_client.dart';
import 'package:fluvie/src/media/runtime/image_resolver_scope.dart';
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

/// A decoder standing in for WebCodecs over a full-HD source, recording the size
/// it was asked to decode at so a test can prove the proxy bound arrived.
class _RecordingClipDecoder implements WebClipDecoder {
  int? decodedWidth;
  int? decodedHeight;

  @override
  Future<ClipMetadata> probe(Uint8List bytes) async =>
      (fps: 30.0, frameCount: 4, width: 1920, height: 1080, hasAudio: false);

  @override
  Future<Map<int, RawFrame>> extractFrames(
    Uint8List bytes,
    List<int> sourceFrames, {
    required int width,
    required int height,
  }) async {
    decodedWidth = width;
    decodedHeight = height;
    return {
      for (final i in sourceFrames)
        i: RawFrame(
          frameIndex: i,
          width: width,
          height: height,
          rgba: Uint8List(width * height * 4)..fillRange(0, width * height * 4, 0xFF),
        ),
    };
  }
}

Video _video() => Video(
  width: 64,
  height: 64,
  scenes: [
    Scene(duration: const Time.frames(4), children: [Clip.asset('clip.mp4')]),
  ],
);

WebImageMediaResolver _resolver(_RecordingClipDecoder decoder, {int? maxEdge}) =>
    WebImageMediaResolver(
      loader: MediaBytesLoader(
        bundle: _MapBundle({'clip.mp4': Uint8List(16)}),
        httpClient: _NoHttp(),
        allowlist: NetworkAllowlist.allowAny(),
      ),
      clipDecoder: decoder,
      maxClipDecodeEdge: maxEdge,
    );

Widget _harness(Widget scope, RenderController controller) => Directionality(
  textDirection: TextDirection.ltr,
  child: RenderControllerScope(
    controller: controller,
    child: Center(child: SizedBox(width: 64, height: 64, child: scope)),
  ),
);

/// Mounts [scope] and waits for the warm-up to land: the byte load, probe,
/// extract, and `ui.decodeImageFromPixels` are all real async work, so they need
/// `runAsync` and real elapsed time before the resolver reaches the tree.
Future<void> _pumpWarmedUp(WidgetTester tester, Widget scope, RenderController controller) async {
  await tester.runAsync(() async {
    await tester.pumpWidget(_harness(scope, controller));
    final deadline = DateTime.now().add(const Duration(seconds: 10));
    while (find.byType(ImageResolverScope).evaluate().isEmpty &&
        DateTime.now().isBefore(deadline)) {
      await Future<void>.delayed(const Duration(milliseconds: 10));
      await tester.pumpWidget(_harness(scope, controller));
    }
  });
  await tester.pump();
}

void main() {
  late RenderController controller;

  setUp(() => controller = RenderController());
  tearDown(() => controller.dispose());

  testWidgets('a preview paints the clip through the capture painter', (tester) async {
    final decoder = _RecordingClipDecoder();

    await _pumpWarmedUp(
      tester,
      PreviewMediaScope(composition: _video(), resolver: _resolver(decoder, maxEdge: 720)),
      controller,
    );

    expect(find.byType(ImageResolverScope), findsOneWidget);
    expect(
      find.byType(flutter.RawImage),
      findsOneWidget,
      reason: 'the clip paints a decoded frame, not its placeholder',
    );
  });

  testWidgets('the proxy bound reaches the decoder, shrinking the decode', (tester) async {
    final decoder = _RecordingClipDecoder();

    await _pumpWarmedUp(
      tester,
      PreviewMediaScope(
        composition: _video(),
        resolver: _resolver(decoder, maxEdge: 360),
        maxClipEdge: 360,
      ),
      controller,
    );

    expect(find.byType(ImageResolverScope), findsOneWidget, reason: 'the warm-up must have landed');
    // 1920x1080 bounded to a 360 long edge: 8.3 MB a frame becomes 0.3 MB. The
    // bound is deliberately not the 720 default, so this fails if it is ignored.
    expect(decoder.decodedWidth, 360);
    expect(decoder.decodedHeight, 202);
  });

  testWidgets('an unbounded preview decodes at the source resolution', (tester) async {
    final decoder = _RecordingClipDecoder();

    await _pumpWarmedUp(
      tester,
      PreviewMediaScope(composition: _video(), resolver: _resolver(decoder)),
      controller,
    );

    expect(find.byType(ImageResolverScope), findsOneWidget, reason: 'the warm-up must have landed');
    expect(decoder.decodedWidth, 1920, reason: 'no bound is the render path: every pixel');
    expect(decoder.decodedHeight, 1080);
  });

  testWidgets('a proxy-decoded clip still lays out at the source size', (tester) async {
    final decoder = _RecordingClipDecoder();

    await _pumpWarmedUp(
      tester,
      // A loose constraint (Center inside the 64x64 box) lets the clip pick its
      // own size, which is where a proxy raster would otherwise shrink it: the
      // preview would lay out at 720x404 while the render lays out at 1920x1080.
      Center(
        child: PreviewMediaScope(
          composition: _video(),
          resolver: _resolver(decoder, maxEdge: 360),
          maxClipEdge: 360,
        ),
      ),
      controller,
    );

    final raw = tester.widget<flutter.RawImage>(find.byType(flutter.RawImage));
    expect(raw.image!.width, 360, reason: 'the raster really is the proxy');
    expect(
      raw.scale,
      closeTo(360 / 1920, 1e-9),
      reason: "RawImage's intrinsic size is image.width / scale, so this cancels the proxy out",
    );
    final render = tester.renderObject<RenderBox>(find.byType(flutter.RawImage));
    expect(
      render.getMaxIntrinsicWidth(double.infinity),
      1920,
      reason: 'preview geometry must equal render geometry, not the proxy size',
    );
    // Not exactly 1080: the decode rounds each side to an even number (405 ->
    // 404) and RawImage has a single scale for both axes, so the short side
    // lands within a rounding of the source. 2.7px in 1080 is 0.25%.
    expect(render.getMaxIntrinsicHeight(double.infinity), closeTo(1080, 3));
  });
}
