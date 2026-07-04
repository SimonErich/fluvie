import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/widgets.dart' hide Image;
import 'package:flutter_test/flutter_test.dart';
import 'package:fluvie/fluvie.dart';
import 'package:fluvie/rendering.dart';

import 'fakes/fake_media_resolver.dart';

void main() {
  testWidgets('captures a composition into an in-memory sandbox + manifest', (tester) async {
    tester.view
      ..physicalSize = const Size(64, 64)
      ..devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    final sandbox = MemoryRenderSandbox();
    late RenderManifest manifest;
    await tester.runAsync(() async {
      manifest = await renderToSandbox(
        composition: const ColoredBox(color: Color(0xFF112233)),
        aspect: Aspect.square,
        frameCount: 3,
        sandbox: sandbox,
        capture: const RepaintBoundaryCaptureService(),
        pumpWidget: tester.pumpWidget,
        pumpFrame: tester.pump,
        longEdge: 64,
      );
    });

    expect(manifest.width, 64);
    expect(manifest.height, 64);
    expect(manifest.frameCount, 3);
    expect(manifest.framesFileName, 'frames.rgba');
    // Video-only on web v1: the plan carries -an, no audio inputs.
    expect(manifest.ffmpegArgs, contains('frames.rgba'));

    final frames = await sandbox.readBytes('frames.rgba');
    expect(frames.length, 3 * 64 * 64 * 4);
    expect(sandbox.names, containsAll(<String>['frames.rgba', 'manifest.json']));
  });

  testWidgets('stages resolved audio into the sandbox and mixes it into the args', (tester) async {
    tester.view
      ..physicalSize = const Size(32, 32)
      ..devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    final sandbox = MemoryRenderSandbox();
    late RenderManifest manifest;
    await tester.runAsync(() async {
      manifest = await renderToSandbox(
        composition: const ColoredBox(color: Color(0xFF000000)),
        aspect: Aspect.square,
        frameCount: 2,
        sandbox: sandbox,
        capture: const RepaintBoundaryCaptureService(),
        pumpWidget: tester.pumpWidget,
        pumpFrame: tester.pump,
        longEdge: 32,
        audioTracks: const [ResolvedAudioTrack(source: 'audio/song.mp3', volume: 0.8)],
        loadAudioBytes: (source) async => Uint8List.fromList(const [1, 2, 3, 4]),
      );
    });

    // The plan mixes audio instead of -an, and the bytes are in the sandbox.
    expect(manifest.ffmpegArgs, isNot(contains('-an')));
    expect(manifest.ffmpegArgs, contains('-filter_complex'));
    final audioName = manifest.ffmpegArgs.firstWhere((a) => a.startsWith('audio_0_'));
    expect(await sandbox.readBytes(audioName), const [1, 2, 3, 4]);
  });

  test('audio tracks without a loader is a caller error, not a silent drop', () {
    expect(
      renderToSandbox(
        composition: const ColoredBox(color: Color(0xFF000000)),
        aspect: Aspect.square,
        frameCount: 1,
        sandbox: MemoryRenderSandbox(),
        capture: const RepaintBoundaryCaptureService(),
        pumpWidget: (_) async {},
        pumpFrame: () async {},
        audioTracks: const [ResolvedAudioTrack(source: 'audio/song.mp3')],
      ),
      throwsArgumentError,
    );
  });

  testWidgets('no audio tracks keeps the plain -an video path', (tester) async {
    tester.view
      ..physicalSize = const Size(32, 32)
      ..devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    final sandbox = MemoryRenderSandbox();
    late RenderManifest manifest;
    await tester.runAsync(() async {
      manifest = await renderToSandbox(
        composition: const ColoredBox(color: Color(0xFF000000)),
        aspect: Aspect.square,
        frameCount: 1,
        sandbox: sandbox,
        capture: const RepaintBoundaryCaptureService(),
        pumpWidget: tester.pumpWidget,
        pumpFrame: tester.pump,
        longEdge: 32,
      );
    });
    expect(manifest.ffmpegArgs, contains('-an'));
  });

  testWidgets('a poster frame plans a poster invocation', (tester) async {
    tester.view
      ..physicalSize = const Size(32, 32)
      ..devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    final sandbox = MemoryRenderSandbox();
    late RenderManifest manifest;
    await tester.runAsync(() async {
      manifest = await renderToSandbox(
        composition: const ColoredBox(color: Color(0xFF000000)),
        aspect: Aspect.square,
        frameCount: 2,
        sandbox: sandbox,
        capture: const RepaintBoundaryCaptureService(),
        pumpWidget: tester.pumpWidget,
        pumpFrame: tester.pump,
        longEdge: 32,
        posterFrame: 1,
      );
    });

    expect(manifest.posterFileName, 'poster.png');
    expect(manifest.posterArgs, isNotNull);
  });

  testWidgets('a resolver pre-resolves declared media so an Image paints', (tester) async {
    tester.view
      ..physicalSize = const Size(64, 64)
      ..devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    final decoded = await _solidGreen();
    addTearDown(decoded.dispose);
    const asset = MediaSource.asset('fixtures/swatch.png');
    final resolver = FakeMediaResolver(
      {asset: (bytes: Uint8List(0), contentHash: 'x')},
      images: {asset: decoded},
    );

    final sandbox = MemoryRenderSandbox();
    await tester.runAsync(() async {
      await renderToSandbox(
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
        frameCount: 2,
        sandbox: sandbox,
        capture: const RepaintBoundaryCaptureService(),
        pumpWidget: tester.pumpWidget,
        pumpFrame: tester.pump,
        longEdge: 64,
        resolver: resolver,
      );
    });

    // The Image was collected, pre-resolved, and painted from the decoded
    // cache: the centre pixel is the swatch green, no async pop-in.
    final bytes = await sandbox.readBytes('frames.rgba');
    const centre = (64 ~/ 2 * 64 + 64 ~/ 2) * 4;
    expect(bytes.sublist(centre, centre + 4), [0x2E, 0xCC, 0x71, 0xFF]);
  });
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
