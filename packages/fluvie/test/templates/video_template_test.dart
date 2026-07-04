// Epic 14.3 (WI-9, D-Template): VideoTemplate<P> turns Props into a Video, and
// the top-level renderTemplate(template, props:) builds that Video and drives
// the same offline capture shell render(video, aspect:) uses. A template is a
// pure function of its Props, so the same Props produce the same Video and the
// same captured frames. Offline through the production shell + RenderService
// (no ffmpeg in the gate).

import 'dart:io';
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/widgets.dart' hide Animation, Clip, Image, Tween;
import 'package:flutter_test/flutter_test.dart';
import 'package:fluvie/src/composition/scene.dart';
import 'package:fluvie/src/composition/video.dart';
import 'package:fluvie/src/core/aspect.dart';
import 'package:fluvie/src/core/time_extensions.dart';
import 'package:fluvie/src/rendering/capture/repaint_boundary_capture_service.dart';
import 'package:fluvie/src/rendering/render_aspect.dart' show RenderAspectResult;
import 'package:fluvie/src/rendering/render_service.dart';
import 'package:fluvie/src/rendering/render_template.dart';
import 'package:fluvie/src/templates/video_template.dart';

/// A trivial template: an `int` of Props maps to a one-scene Video whose only
/// child is a full-canvas swatch whose color encodes the prop, so a captured
/// frame proves which Props built it.
final class _SwatchTemplate extends VideoTemplate<int> {
  const _SwatchTemplate();

  @override
  Video build(int props) => Video(
    width: 32,
    height: 32,
    scenes: [
      Scene(
        duration: 2.frames,
        children: [ColoredBox(color: Color(props), child: const SizedBox.expand())],
      ),
    ],
  );
}

/// A template whose Props ask for an empty Video, so renderTemplate surfaces the
/// `Video` constructor's own ArgumentError unchanged (no scenes -> no duration).
final class _EmptyTemplate extends VideoTemplate<int> {
  const _EmptyTemplate();

  @override
  Video build(int props) => Video(width: 32, height: 32, scenes: const []);
}

/// Drives [template] for [props] through the offline shell and returns the raw
/// captured frames plus the size the render derived for [aspect].
Future<({Uint8List frames, int width, int height})> _render(
  WidgetTester tester, {
  required VideoTemplate<int> template,
  required int props,
  Aspect aspect = Aspect.reels,
  int longEdge = 32,
  int frameCount = 2,
}) async {
  final size = aspect.sizeFor(longEdge);
  tester.view.physicalSize = ui.Size(size.width.toDouble(), size.height.toDouble());
  tester.view.devicePixelRatio = 1.0;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);

  final dir = Directory.systemTemp.createTempSync('fluvie_render_template_');
  addTearDown(() => dir.deleteSync(recursive: true));

  late final RenderAspectResult result;
  await tester.runAsync(() async {
    result = await renderTemplate(
      template,
      props: props,
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
  group('VideoTemplate<P> builds a Video from Props', () {
    test('build(props) returns a Video', () {
      final video = const _SwatchTemplate().build(0xFFFF0000);
      expect(video, isA<Video>());
      expect(video.scenes, hasLength(1));
    });

    test('different Props build different Videos', () {
      final a = const _SwatchTemplate().build(0xFFFF0000);
      final b = const _SwatchTemplate().build(0xFF00FF00);
      // The same template, but the trees differ — Props flow into build().
      expect(identical(a, b), isFalse);
    });
  });

  group('renderTemplate drives the shell over template.build(props)', () {
    testWidgets('produces the full frame buffer', (tester) async {
      final r = await _render(tester, template: const _SwatchTemplate(), props: 0xFFFF0000);
      expect(r.frames.length, 2 * r.width * r.height * 4);
    });

    testWidgets('the rendered Props color the frame', (tester) async {
      final red = await _render(tester, template: const _SwatchTemplate(), props: 0xFFFF0000);
      final blue = await _render(tester, template: const _SwatchTemplate(), props: 0xFF0000FF);
      expect(red.frames.sublist(0, 4), const [0xFF, 0x00, 0x00, 0xFF]);
      expect(blue.frames.sublist(0, 4), const [0x00, 0x00, 0xFF, 0xFF]);
    });

    testWidgets('defaults to the canonical reels aspect', (tester) async {
      final dir = Directory.systemTemp.createTempSync('fluvie_render_template_aspect_');
      addTearDown(() => dir.deleteSync(recursive: true));
      tester.view.physicalSize = const ui.Size(18, 32);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      late final RenderAspectResult result;
      await tester.runAsync(() async {
        result = await renderTemplate(
          const _SwatchTemplate(),
          props: 0xFFFF0000,
          longEdge: 32,
          frameCount: 1,
          outDir: dir,
          service: RenderService(capture: const RepaintBoundaryCaptureService()),
          pumpWidget: tester.pumpWidget,
          pumpFrame: () => tester.pump(),
        );
      });
      // reels (9:16) at longEdge 32 -> 18 x 32.
      expect((result.config.width, result.config.height), (18, 32));
    });

    testWidgets('invalid Props surface the Video error', (tester) async {
      final dir = Directory.systemTemp.createTempSync('fluvie_render_template_bad_');
      addTearDown(() => dir.deleteSync(recursive: true));
      await tester.runAsync(() async {
        await expectLater(
          () => renderTemplate(
            const _EmptyTemplate(),
            props: 0,
            frameCount: 1,
            outDir: dir,
            service: RenderService(capture: const RepaintBoundaryCaptureService()),
            pumpWidget: tester.pumpWidget,
            pumpFrame: () => tester.pump(),
          ),
          throwsArgumentError,
        );
      });
    });
  });

  group('template determinism', () {
    testWidgets('the same Props render byte-identical frames', (tester) async {
      final first = await _render(tester, template: const _SwatchTemplate(), props: 0xFF00FF00);
      final second = await _render(tester, template: const _SwatchTemplate(), props: 0xFF00FF00);
      expect(first.frames, orderedEquals(second.frames));
    });
  });
}
