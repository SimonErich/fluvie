// Epic 14.2 (WI-8, D-Render): the top-level render(video, aspect:) re-derives
// the canvas size from Aspect.sizeFor, mounts an AspectScope over the
// composition, and runs the capture shell once for that aspect. Timing and
// animations resolve identically across aspects (the same plan) — only layout
// branches via Adaptive / AspectScope.of. Renders offline through the production
// shell + RenderService.captureToDirectory (no ffmpeg in the gate). Per aspect:
// the size re-derives, an Adaptive composition branches, and a render twice is
// byte-identical.

import 'dart:io';
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/widgets.dart' hide Image;
import 'package:flutter_test/flutter_test.dart';
import 'package:fluvie/src/audio/audio.dart';
import 'package:fluvie/src/composition/adaptive.dart';
import 'package:fluvie/src/composition/scene.dart';
import 'package:fluvie/src/composition/video.dart';
import 'package:fluvie/src/core/aspect.dart';
import 'package:fluvie/src/core/audio/audio_source.dart';
import 'package:fluvie/src/core/contracts/media_resolver.dart';
import 'package:fluvie/src/core/time.dart';
import 'package:fluvie/src/core/time_extensions.dart';
import 'package:fluvie/src/core/trigger.dart';
import 'package:fluvie/src/rendering/capture/render_manifest.dart';
import 'package:fluvie/src/rendering/capture/repaint_boundary_capture_service.dart';
import 'package:fluvie/src/rendering/no_media_resolver.dart';
import 'package:fluvie/src/rendering/render_aspect.dart';
import 'package:fluvie/src/rendering/render_service.dart';

import 'fakes/fake_media_resolver.dart';

/// A composition that paints a different solid color per aspect, so a captured
/// frame proves which branch laid out.
Widget _adaptiveSwatch() => Adaptive(
  reels: () => const ColoredBox(color: Color(0xFFFF0000)),
  square: () => const ColoredBox(color: Color(0xFF00FF00)),
  landscape: () => const ColoredBox(color: Color(0xFF0000FF)),
  portrait45: () => const ColoredBox(color: Color(0xFFFFFF00)),
);

/// Drives a render for [aspect] through the offline shell and returns the raw
/// captured frames plus the size the render derived.
Future<({Uint8List frames, int width, int height})> _render(
  WidgetTester tester, {
  required Widget composition,
  required Aspect aspect,
  int longEdge = 32,
  int frameCount = 2,
}) async {
  final size = aspect.sizeFor(longEdge);
  tester.view.physicalSize = ui.Size(size.width.toDouble(), size.height.toDouble());
  tester.view.devicePixelRatio = 1.0;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);

  final dir = Directory.systemTemp.createTempSync('fluvie_render_aspect_');
  addTearDown(() => dir.deleteSync(recursive: true));

  late final RenderAspectResult result;
  await tester.runAsync(() async {
    result = await render(
      composition: composition,
      aspect: aspect,
      longEdge: longEdge,
      frameCount: frameCount,
      outDir: dir,
      service: RenderService(capture: const RepaintBoundaryCaptureService()),
      pumpWidget: tester.pumpWidget,
      pumpFrame: () => tester.pump(),
    );
  });

  final frames = File('${dir.path}/frames.rgba').readAsBytesSync();
  return (frames: frames, width: result.config.width, height: result.config.height);
}

void main() {
  group('renderAspect re-derives the size', () {
    testWidgets('landscape derives a 16:9 canvas', (tester) async {
      final r = await _render(
        tester,
        composition: _adaptiveSwatch(),
        aspect: Aspect.landscape,
      );
      expect((r.width, r.height), (32, 18));
    });

    testWidgets('reels derives a 9:16 canvas', (tester) async {
      final r = await _render(
        tester,
        composition: _adaptiveSwatch(),
        aspect: Aspect.reels,
      );
      expect((r.width, r.height), (18, 32));
    });

    testWidgets('square derives a 1:1 canvas', (tester) async {
      final r = await _render(
        tester,
        composition: _adaptiveSwatch(),
        aspect: Aspect.square,
      );
      expect((r.width, r.height), (32, 32));
    });
  });

  group('renderAspect branches an Adaptive composition per aspect', () {
    testWidgets('each aspect paints its own branch color', (tester) async {
      final reels = await _render(tester, composition: _adaptiveSwatch(), aspect: Aspect.reels);
      final square = await _render(tester, composition: _adaptiveSwatch(), aspect: Aspect.square);
      final land = await _render(tester, composition: _adaptiveSwatch(), aspect: Aspect.landscape);

      // The first pixel (top-left) carries the branch color: red / green / blue.
      expect(reels.frames.sublist(0, 4), const [0xFF, 0x00, 0x00, 0xFF]);
      expect(square.frames.sublist(0, 4), const [0x00, 0xFF, 0x00, 0xFF]);
      expect(land.frames.sublist(0, 4), const [0x00, 0x00, 0xFF, 0xFF]);
    });
  });

  group('per-aspect rendering', () {
    testWidgets('renders an Adaptive composition for the square aspect', (tester) async {
      final square = await _render(tester, composition: _adaptiveSwatch(), aspect: Aspect.square);
      expect(square.frames.length, 2 * 32 * 32 * 4);
    });
  });

  group('render(video, aspect:) stages the audio mix (AUDMIX-WIRE)', () {
    const song = AudioSource.asset('audio/song.mp3');

    testWidgets('a Video with Audio.music stages the mix into the manifest', (tester) async {
      final src = _tempFile('song.bin', const [1, 2, 3]);
      final manifest = await _renderManifest(
        tester,
        video: _audioVideo([const Audio.music('audio/song.mp3')]),
        resolver: FakeMediaResolver(const {}, audioPaths: {song: src.path}),
      );
      expect(manifest.ffmpegArgs, contains('-filter_complex'));
      expect(manifest.ffmpegArgs, containsAllInOrder(<String>['-map', '[aout]']));
      expect(manifest.ffmpegArgs, isNot(contains('-an')));
    });

    testWidgets('an Audio.sfx(at: 1s) lands an adelay in the mix args', (tester) async {
      final src = _tempFile('pop.bin', const [4, 5, 6]);
      final manifest = await _renderManifest(
        tester,
        video: _audioVideo([Audio.sfx('audio/song.mp3', at: Trigger.at(1.seconds))]),
        resolver: FakeMediaResolver(const {}, audioPaths: {song: src.path}),
      );
      final graph = manifest.ffmpegArgs[manifest.ffmpegArgs.indexOf('-filter_complex') + 1];
      expect(graph, contains('adelay=1000|1000'));
    });

    testWidgets('a Video with no audio keeps the -an plan', (tester) async {
      final manifest = await _renderManifest(tester, video: _audioVideo(const []));
      expect(manifest.ffmpegArgs, contains('-an'));
      expect(manifest.ffmpegArgs, isNot(contains('-filter_complex')));
    });

    testWidgets('DETERMINISM: the same audio Video yields identical args twice', (tester) async {
      final src = _tempFile('det.bin', const [7, 7, 7]);
      FakeMediaResolver resolver() => FakeMediaResolver(const {}, audioPaths: {song: src.path});
      final a = await _renderManifest(
        tester,
        video: _audioVideo([const Audio.music('audio/song.mp3')]),
        resolver: resolver(),
      );
      final b = await _renderManifest(
        tester,
        video: _audioVideo([const Audio.music('audio/song.mp3')]),
        resolver: resolver(),
      );
      expect(a.ffmpegArgs, b.ffmpegArgs);
    });
  });
}

/// A bare 30-frame [Video] (no [Directionality] wrap) carrying [audio], so
/// `render` can collect its tracks straight from the composition.
Video _audioVideo(List<Audio> audio) => Video(
  width: 16,
  height: 16,
  audio: audio,
  scenes: const [
    Scene(
      duration: Time.frames(30),
      children: [ColoredBox(color: Color(0xFF101010), child: SizedBox.expand())],
    ),
  ],
);

/// Drives `render` over [video] for a square aspect and returns the manifest.
Future<RenderManifest> _renderManifest(
  WidgetTester tester, {
  required Video video,
  MediaResolver? resolver,
}) async {
  tester.view.physicalSize = const ui.Size(16, 16);
  tester.view.devicePixelRatio = 1.0;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
  final dir = Directory.systemTemp.createTempSync('fluvie_render_aspect_audio_');
  addTearDown(() => dir.deleteSync(recursive: true));
  late final RenderAspectResult result;
  await tester.runAsync(() async {
    result = await render(
      composition: video,
      aspect: Aspect.square,
      longEdge: 16,
      frameCount: 2,
      outDir: dir,
      service: RenderService(
        capture: const RepaintBoundaryCaptureService(),
        media: resolver ?? const NoMediaResolver(),
      ),
      pumpWidget: tester.pumpWidget,
      pumpFrame: () => tester.pump(),
    );
  });
  return result.manifest;
}

File _tempFile(String name, List<int> bytes) {
  final dir = Directory.systemTemp.createTempSync('fluvie_render_aspect_src_');
  addTearDown(() => dir.deleteSync(recursive: true));
  return File('${dir.path}/$name')..writeAsBytesSync(bytes);
}
