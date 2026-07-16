// renderVideo is the one capture entry a host drives: it derives the whole
// render from the Video itself (geometry, frame count, media, audio) and asks
// the host only for the mechanics it alone can supply (pump, view, runAsync).
// These run offline through the production shell + RenderService — no ffmpeg in
// the gate — and pin the contract a generated harness depends on: the declared
// size wins unless an aspect overrides it, a media-less composition never builds
// a resolver, an injected resolver is never disposed, and the untrusted bound is
// enforced with the final post-aspect canvas.

import 'dart:io';
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/widgets.dart' hide Image;
import 'package:flutter_test/flutter_test.dart';
import 'package:fluvie/src/composition/scene.dart';
import 'package:fluvie/src/composition/video.dart';
import 'package:fluvie/src/core/aspect.dart';
import 'package:fluvie/src/core/time_extensions.dart';
import 'package:fluvie/src/core/video_size.dart';
import 'package:fluvie/src/elements/snapshot/snapshot.dart';
import 'package:fluvie/src/rendering/capture/render_manifest.dart';
import 'package:fluvie/src/rendering/render_video.dart';

/// A media-less composition: one scene of a solid color, so it renders with no
/// resolver and no ffmpeg.
Video _swatch({VideoSize size = const VideoSize(16, 16), int fps = 30}) => Video(
  size: size,
  fps: fps,
  scenes: [
    Scene(
      duration: 2.frames,
      children: const [ColoredBox(color: Color(0xFF00FF00))],
    ),
  ],
);

/// Drives one render through [renderVideo], returning its manifest, the raw
/// captured frames, and any cache report.
Future<({RenderManifest manifest, Uint8List frames, (int, int)? cacheReport})> _render(
  WidgetTester tester, {
  required Video video,
  Aspect? aspect,
  int? frameCountOverride,
  bool cacheEnabled = false,
}) async {
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
  final dir = Directory.systemTemp.createTempSync('fluvie_render_video_');
  addTearDown(() => dir.deleteSync(recursive: true));
  // A temp cache root so a test never reads or writes the developer's real one.
  final cacheRoot = Directory.systemTemp.createTempSync('fluvie_render_video_cache_');
  addTearDown(() => cacheRoot.deleteSync(recursive: true));

  (int, int)? report;
  final manifest = await renderVideo(
    video: video,
    outDir: dir,
    aspect: aspect,
    frameCountOverride: frameCountOverride,
    cacheEnabled: cacheEnabled,
    cacheRoot: cacheRoot,
    setViewSize: (width, height) {
      tester.view.physicalSize = ui.Size(width.toDouble(), height.toDouble());
      tester.view.devicePixelRatio = 1.0;
    },
    pumpWidget: tester.pumpWidget,
    pumpFrame: () => tester.pump(),
    runAsync: tester.runAsync,
    onCacheReport: (hits, total) => report = (hits, total),
  );
  return (
    manifest: manifest,
    frames: File('${dir.path}/frames.rgba').readAsBytesSync(),
    cacheReport: report,
  );
}

void main() {
  group('geometry', () {
    testWidgets('the declared size wins when no aspect is given', (tester) async {
      final r = await _render(tester, video: _swatch(size: const VideoSize(20, 12)));
      expect((r.manifest.width, r.manifest.height), (20, 12));
    });

    testWidgets('an aspect re-derives the canvas from the longer declared edge', (tester) async {
      // longEdge is 32 (the declared width), so landscape derives 32x18.
      final r = await _render(
        tester,
        video: _swatch(size: const VideoSize(32, 8)),
        aspect: Aspect.landscape,
      );
      expect((r.manifest.width, r.manifest.height), (32, 18));
    });

    testWidgets('reels re-derives a 9:16 canvas from the same video', (tester) async {
      final r = await _render(
        tester,
        video: _swatch(size: const VideoSize(32, 8)),
        aspect: Aspect.reels,
      );
      expect((r.manifest.width, r.manifest.height), (18, 32));
    });
  });

  group('frames', () {
    testWidgets('the video totalFrames drives the capture', (tester) async {
      final r = await _render(tester, video: _swatch());
      expect(r.manifest.frameCount, 2);
      // 16x16 RGBA per frame.
      expect(r.frames.length, 16 * 16 * 4 * 2);
    });

    testWidgets('frameCountOverride shortens the render', (tester) async {
      final r = await _render(tester, video: _swatch(), frameCountOverride: 1);
      expect(r.manifest.frameCount, 1);
      expect(r.frames.length, 16 * 16 * 4);
    });

    testWidgets('a media-less composition renders without a resolver', (tester) async {
      // No ffmpeg, no bundle: reaching for either would throw rather than paint.
      final r = await _render(tester, video: _swatch());
      expect(r.frames, isNotEmpty);
    });

    testWidgets('rendering the same video twice is byte-identical', (tester) async {
      final a = await _render(tester, video: _swatch());
      final b = await _render(tester, video: _swatch());
      expect(a.frames, equals(b.frames));
    });
  });

  group('snapshots', () {
    testWidgets('a Snapshot over plain widgets rasterizes with no resolver', (tester) async {
      // The pre-pass must not be gated on the resolver: a Snapshot whose child is
      // plain widgets declares no MediaSource and no SnapshotSource, so nothing
      // builds a resolver for it, but it still needs its raster before frame 0 or
      // Snapshot.build throws "cannot render in capture without a
      // SnapshotCaptureScope".
      final video = Video(
        size: const VideoSize(16, 16),
        scenes: [
          Scene(
            duration: 2.frames,
            children: const [
              Positioned.fill(
                child: Snapshot(child: ColoredBox(color: Color(0xFF00FF00))),
              ),
            ],
          ),
        ],
      );
      final r = await _render(tester, video: video);
      expect(r.frames.length, 16 * 16 * 4 * 2);
    });
  });

  group('cache report', () {
    testWidgets('reports no hits when the cache is off', (tester) async {
      final r = await _render(tester, video: _swatch());
      expect(r.cacheReport, (0, 2));
    });

    testWidgets('reports hits when a warm cache replays the frames', (tester) async {
      final dir = Directory.systemTemp.createTempSync('fluvie_render_video_warm_');
      addTearDown(() => dir.deleteSync(recursive: true));
      final cacheRoot = Directory.systemTemp.createTempSync('fluvie_render_video_warm_cache_');
      addTearDown(() => cacheRoot.deleteSync(recursive: true));
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      (int, int)? report;
      Future<void> once() async {
        await renderVideo(
          video: _swatch(),
          outDir: dir,
          cacheEnabled: true,
          cacheRoot: cacheRoot,
          setViewSize: (width, height) {
            tester.view.physicalSize = ui.Size(width.toDouble(), height.toDouble());
            tester.view.devicePixelRatio = 1.0;
          },
          pumpWidget: tester.pumpWidget,
          pumpFrame: () => tester.pump(),
          runAsync: tester.runAsync,
          onCacheReport: (hits, total) => report = (hits, total),
        );
      }

      await once();
      expect(report, (0, 2), reason: 'a cold cache captures every frame');
      await once();
      expect(report, (2, 2), reason: 'a warm cache replays both frames');
    });
  });

  group('assertRenderWithinBounds', () {
    test('a trusted render is never bounded', () {
      expect(
        () => assertRenderWithinBounds(
          untrusted: false,
          width: 999999,
          height: 999999,
          frameCount: 999999,
        ),
        returnsNormally,
      );
    });

    test('an untrusted render within the bounds passes', () {
      expect(
        () => assertRenderWithinBounds(untrusted: true, width: 1080, height: 1920, frameCount: 120),
        returnsNormally,
      );
    });

    test('an untrusted canvas over the per-axis limit is rejected', () {
      expect(
        () => assertRenderWithinBounds(untrusted: true, width: 7681, height: 8, frameCount: 1),
        throwsA(isA<StateError>()),
      );
    });

    test('a per-axis check runs before any multiply, so an overflow cannot slip past', () {
      // width*height*4*frameCount wraps to a small value in 64-bit; the per-axis
      // bound is what catches it.
      expect(
        () => assertRenderWithinBounds(
          untrusted: true,
          width: 1 << 31,
          height: 1 << 31,
          frameCount: 4,
        ),
        throwsA(isA<StateError>()),
      );
    });

    test('an untrusted render over the frame limit is rejected', () {
      expect(
        () => assertRenderWithinBounds(
          untrusted: true,
          width: 8,
          height: 8,
          frameCount: 60 * 60 * 4 + 1,
        ),
        throwsA(isA<StateError>()),
      );
    });

    test('an untrusted render over the total byte budget is rejected', () {
      expect(
        () => assertRenderWithinBounds(
          untrusted: true,
          width: 7680,
          height: 4320,
          frameCount: 60 * 60 * 4,
        ),
        throwsA(isA<StateError>()),
      );
    });
  });
}
