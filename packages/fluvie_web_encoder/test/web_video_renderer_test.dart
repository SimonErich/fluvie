import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/widgets.dart' hide Animation, Image;
import 'package:flutter_test/flutter_test.dart';
import 'package:fluvie/fluvie.dart';
import 'package:fluvie_web_encoder/fluvie_web_encoder.dart';

import 'fake_wasm_runtime.dart';

/// A [WebAudioMaterializer] that returns fixed bytes for any source.
class _FakeAudioMaterializer implements WebAudioMaterializer {
  final List<String> requested = [];
  @override
  Future<Uint8List> materialize(String source) async {
    requested.add(source);
    return Uint8List.fromList(const [1, 2, 3, 4]);
  }
}

Video _audioVideo() => Video(
  size: VideoSize.square,
  audio: const [Audio.music('audio/song.wav')],
  scenes: [
    Scene(duration: 1.seconds, children: const [SizedBox.shrink()]),
  ],
);

/// A media resolver that records what it pre-resolved and paints one decoded
/// image — enough to prove the renderer collects, pre-resolves, and mounts it.
class _ImageOnlyResolver implements MediaResolver {
  _ImageOnlyResolver(this.image);

  final ui.Image image;
  final List<MediaSource> preResolved = [];

  @override
  Future<void> preResolveAll(Iterable<MediaSource> sources) async => preResolved.addAll(sources);

  @override
  ui.Image decodedImageFor(MediaSource source) => image;

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

/// A solid green (0xFF2ECC71) swatch the resolver paints from its cache.
Future<ui.Image> _solidGreen() async {
  final recorder = ui.PictureRecorder();
  ui.Canvas(recorder).drawRect(
    const ui.Rect.fromLTWH(0, 0, 4, 4),
    ui.Paint()..color = const ui.Color(0xFF2ECC71),
  );
  return recorder.endRecording().toImage(4, 4);
}

/// A [WebCaptureHost] backed by the widget tester: drives real capture on the VM
/// without the engine-only off-screen host.
class _TesterHost implements WebCaptureHost {
  _TesterHost(this.tester, this.size);

  final WidgetTester tester;
  final Size size;
  bool disposed = false;

  @override
  Future<void> mount(Widget tree) async {
    tester.view
      ..physicalSize = size
      ..devicePixelRatio = 1.0;
    await tester.pumpWidget(tree);
  }

  @override
  Future<void> pumpFrame() => tester.pump();

  @override
  Future<void> dispose() async {
    disposed = true;
    tester.view
      ..resetPhysicalSize()
      ..resetDevicePixelRatio();
  }
}

/// A host whose dispose throws after tearing down, to prove a cleanup failure is
/// reported through `onWarning` and never masks a finished render.
class _ThrowingDisposeHost extends _TesterHost {
  _ThrowingDisposeHost(super.tester, super.size);

  @override
  Future<void> dispose() async {
    await super.dispose();
    throw StateError('dispose boom');
  }
}

void main() {
  testWidgets('captures a Video and encodes it to MP4 bytes', (tester) async {
    final runtime = FakeWasmRuntime();
    late _TesterHost host;
    final renderer = WebVideoRenderer(
      encoder: WebVideoEncoder(runtime: runtime),
      hostFactory: (size) => host = _TesterHost(tester, size),
    );

    final bytes = await tester.runAsync(
      () => renderer.render(
        composition: const ColoredBox(color: Color(0xFF112233)),
        aspect: Aspect.square,
        duration: const Duration(milliseconds: 100),
        longEdge: 64,
      ),
    );

    expect(bytes, isNotEmpty);
    expect(runtime.files['frames.rgba']!.length, 3 * 64 * 64 * 4);
    expect(runtime.lastArgs, contains('frames.rgba'));
    expect(host.disposed, isTrue);
  });

  testWidgets('collects, pre-resolves, and paints declared image media', (tester) async {
    final decoded = await _solidGreen();
    addTearDown(decoded.dispose);
    final resolver = _ImageOnlyResolver(decoded);
    final runtime = FakeWasmRuntime();
    final renderer = WebVideoRenderer(
      encoder: WebVideoEncoder(runtime: runtime),
      hostFactory: (size) => _TesterHost(tester, size),
      mediaResolver: resolver,
    );

    await tester.runAsync(
      () => renderer.render(
        composition: Video(
          size: VideoSize.square,
          scenes: [
            Scene(
              duration: const Time.frames(2),
              children: [Image.asset('fixtures/swatch.png', fit: BoxFit.fill)],
            ),
          ],
        ),
        aspect: Aspect.square,
        duration: const Duration(milliseconds: 100),
        longEdge: 64,
      ),
    );

    // The declared image was collected and pre-resolved before frame 0 ...
    expect(resolver.preResolved, contains(const MediaSource.asset('fixtures/swatch.png')));
    // ... and painted from the decoded cache: the centre pixel is swatch green.
    final frames = runtime.files['frames.rgba']!;
    const centre = (64 ~/ 2 * 64 + 64 ~/ 2) * 4;
    expect(frames.sublist(centre, centre + 4), [0x2E, 0xCC, 0x71, 0xFF]);
  });

  testWidgets('reports per-frame capture progress, then encoding and complete', (tester) async {
    final events = <RenderProgress>[];
    final renderer = WebVideoRenderer(
      encoder: WebVideoEncoder(runtime: FakeWasmRuntime()),
      hostFactory: (size) => _TesterHost(tester, size),
    );

    await tester.runAsync(
      () => renderer.render(
        composition: const ColoredBox(color: Color(0xFF112233)),
        aspect: Aspect.square,
        duration: const Duration(milliseconds: 100),
        longEdge: 64,
        onProgress: events.add,
      ),
    );

    expect(events.last.phase, RenderPhase.complete);
    expect(events[events.length - 2].phase, RenderPhase.encoding);
    final captures = events.where((e) => e.phase == RenderPhase.capturing).toList();
    expect(captures, isNotEmpty);
    expect(captures.last.completedFrames, captures.last.totalFrames);
  });

  testWidgets('a cleanup failure is reported, not masked, and the render succeeds', (tester) async {
    final warnings = <String>[];
    final previous = WebVideoRenderer.onWarning;
    WebVideoRenderer.onWarning = warnings.add;
    addTearDown(() => WebVideoRenderer.onWarning = previous);

    final renderer = WebVideoRenderer(
      encoder: WebVideoEncoder(runtime: FakeWasmRuntime()),
      hostFactory: (size) => _ThrowingDisposeHost(tester, size),
    );

    final bytes = await tester.runAsync(
      () => renderer.render(
        composition: const ColoredBox(color: Color(0xFF112233)),
        aspect: Aspect.square,
        duration: const Duration(milliseconds: 100),
        longEdge: 64,
      ),
    );

    expect(bytes, isNotEmpty, reason: 'a cleanup hiccup must not fail a finished render');
    expect(warnings.single, contains('Cleanup after render failed'));
    expect(warnings.single, contains('dispose boom'));
  });

  testWidgets('rounds a sub-frame duration up to one frame', (tester) async {
    final runtime = FakeWasmRuntime();
    final renderer = WebVideoRenderer(
      encoder: WebVideoEncoder(runtime: runtime),
      hostFactory: (size) => _TesterHost(tester, size),
    );

    await tester.runAsync(
      () => renderer.render(
        composition: const ColoredBox(color: Color(0xFF000000)),
        aspect: Aspect.square,
        duration: const Duration(milliseconds: 1),
        longEdge: 64,
      ),
    );

    expect(runtime.files['frames.rgba']!.length, 64 * 64 * 4); // exactly 1 frame
  });

  testWidgets('with audio:true it stages the track and mixes it into the args', (tester) async {
    final runtime = FakeWasmRuntime();
    final materializer = _FakeAudioMaterializer();
    final renderer = WebVideoRenderer(
      encoder: WebVideoEncoder(runtime: runtime),
      hostFactory: (size) => _TesterHost(tester, size),
      audioMaterializer: materializer,
    );

    await tester.runAsync(
      () => renderer.render(
        composition: _audioVideo(),
        aspect: Aspect.square,
        duration: const Duration(milliseconds: 100),
        longEdge: 48,
        audio: true,
      ),
    );

    expect(materializer.requested, ['audio/song.wav']);
    expect(runtime.lastArgs, contains('-filter_complex'));
    expect(runtime.files.keys.any((name) => name.startsWith('audio_0_')), isTrue);
  });

  testWidgets('a Video with audio but audio:false renders silent and warns once', (tester) async {
    final warnings = <String>[];
    final previous = WebVideoRenderer.onWarning;
    WebVideoRenderer.onWarning = warnings.add;
    addTearDown(() => WebVideoRenderer.onWarning = previous);

    final runtime = FakeWasmRuntime();
    final renderer = WebVideoRenderer(
      encoder: WebVideoEncoder(runtime: runtime),
      hostFactory: (size) => _TesterHost(tester, size),
      audioMaterializer: _FakeAudioMaterializer(),
    );

    await tester.runAsync(
      () => renderer.render(
        composition: _audioVideo(),
        aspect: Aspect.square,
        duration: const Duration(milliseconds: 100),
        longEdge: 48,
      ),
    );

    expect(warnings, hasLength(1));
    expect(runtime.lastArgs, contains('-an'));
  });

  testWidgets('warnOnDroppedAudio:false suppresses the silent-render warning', (tester) async {
    final warnings = <String>[];
    final previous = WebVideoRenderer.onWarning;
    WebVideoRenderer.onWarning = warnings.add;
    addTearDown(() => WebVideoRenderer.onWarning = previous);

    final renderer = WebVideoRenderer(
      encoder: WebVideoEncoder(runtime: FakeWasmRuntime()),
      hostFactory: (size) => _TesterHost(tester, size),
      audioMaterializer: _FakeAudioMaterializer(),
    );

    await tester.runAsync(
      () => renderer.render(
        composition: _audioVideo(),
        aspect: Aspect.square,
        duration: const Duration(milliseconds: 100),
        longEdge: 48,
        warnOnDroppedAudio: false,
      ),
    );

    expect(warnings, isEmpty);
  });

  testWidgets('a non-MP4 export with audio:true drops audio and warns', (tester) async {
    final warnings = <String>[];
    final previous = WebVideoRenderer.onWarning;
    WebVideoRenderer.onWarning = warnings.add;
    addTearDown(() => WebVideoRenderer.onWarning = previous);

    final runtime = FakeWasmRuntime();
    final renderer = WebVideoRenderer(
      encoder: WebVideoEncoder(runtime: runtime),
      hostFactory: (size) => _TesterHost(tester, size),
      audioMaterializer: _FakeAudioMaterializer(),
    );

    await tester.runAsync(
      () => renderer.render(
        composition: _audioVideo(),
        aspect: Aspect.square,
        duration: const Duration(milliseconds: 100),
        longEdge: 48,
        audio: true,
        export: const Export.gif(),
      ),
    );

    expect(warnings, hasLength(1));
    expect(warnings.single, contains('MP4'));
    expect(runtime.files.keys.any((name) => name.startsWith('audio_0_')), isFalse);
  });

  test('rejects a non-positive fps', () {
    final renderer = WebVideoRenderer(encoder: WebVideoEncoder(runtime: FakeWasmRuntime()));
    expect(
      renderer.render(
        composition: const SizedBox(),
        aspect: Aspect.square,
        duration: const Duration(seconds: 1),
        fps: 0,
      ),
      throwsArgumentError,
    );
  });

  test('rejects a non-positive duration', () {
    final renderer = WebVideoRenderer(encoder: WebVideoEncoder(runtime: FakeWasmRuntime()));
    expect(
      renderer.render(
        composition: const SizedBox(),
        aspect: Aspect.square,
        duration: Duration.zero,
      ),
      throwsArgumentError,
    );
  });
}
