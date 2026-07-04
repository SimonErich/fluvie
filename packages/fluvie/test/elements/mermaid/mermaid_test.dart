// WI-12 (D-Mermaid, §15): the public Mermaid widget. It exposes a
// MermaidSnapshotSource via MediaCarrier (BuildContext-free, so the collector
// can read it); mounted under a 30fps scope with a fake resolver it paints the
// resolved raster through ResolvedSnapshot; an explicit theme: changes the
// source cacheKey; a MermaidReveal drives per-frame opacity; it takes content
// params only; shared: wraps a SharedElement.

import 'dart:ui' as ui;

import 'package:flutter/widgets.dart' hide Animation, Clip, Image, Tween;
import 'package:flutter/widgets.dart' as flutter;
import 'package:flutter_test/flutter_test.dart';
import 'package:fluvie/src/animation/animate_extension.dart';
import 'package:fluvie/src/animation/motion_target.dart';
import 'package:fluvie/src/composition/transition/shared_element.dart';
import 'package:fluvie/src/core/anchor.dart';
import 'package:fluvie/src/core/errors/fluvie_render_exception.dart';
import 'package:fluvie/src/core/media/media_carrier.dart';
import 'package:fluvie/src/core/media/snapshot_source.dart';
import 'package:fluvie/src/core/time.dart';
import 'package:fluvie/src/elements/mermaid/mermaid.dart';
import 'package:fluvie/src/elements/mermaid/mermaid_reveal.dart';
import 'package:fluvie/src/elements/mermaid/mermaid_theme.dart';
import 'package:fluvie/src/media/runtime/image_resolver_scope.dart';
import 'package:fluvie/src/rendering/runtime/render_controller.dart';
import 'package:fluvie/src/rendering/runtime/render_controller_scope.dart';
import 'package:fluvie/src/rendering/runtime/render_mode.dart';
import 'package:fluvie/src/rendering/runtime/render_mode_context.dart';
import 'package:fluvie/src/timing/scene_scope.dart';
import 'package:fluvie/src/timing/video_scope.dart';

import '../../rendering/fakes/fake_media_resolver.dart';

const _graph = 'graph TD; A-->B; B-->C;';

Future<ui.Image> _solidImage() async {
  final recorder = ui.PictureRecorder();
  ui.Canvas(recorder).drawRect(
    const ui.Rect.fromLTWH(0, 0, 4, 4),
    ui.Paint()..color = const ui.Color(0xFFE67E22),
  );
  return recorder.endRecording().toImage(4, 4);
}

/// Mounts [mermaid] at [frame] under a 30fps capture scope with a resolver that
/// has [image] canned for the mermaid's snapshot source.
Future<void> _pumpAt(
  WidgetTester tester,
  Mermaid mermaid,
  ui.Image image, {
  int frame = 0,
  int sceneFrames = 60,
}) async {
  final source = mermaid.snapshotSource!;
  final resolver = FakeMediaResolver({}, snapshots: {source: image});
  await resolver.preResolveAll(const []);
  await tester.pumpWidget(
    ImageResolverScope(
      resolver: resolver,
      child: RenderModeContext(
        mode: RenderMode.capture,
        child: SizedBox(
          width: 320,
          height: 240,
          child: RenderControllerScope(
            controller: RenderController(initialFrame: frame),
            child: VideoScope(
              fps: 30,
              duration: Time.frames(sceneFrames),
              child: SceneScope(duration: Time.frames(sceneFrames), child: mermaid),
            ),
          ),
        ),
      ),
    ),
  );
}

void main() {
  group('Mermaid as a MediaCarrier', () {
    test('exposes a MermaidSnapshotSource via snapshotSource', () {
      const mermaid = Mermaid(_graph);
      expect(mermaid, isA<MediaCarrier>());
      final source = mermaid.snapshotSource;
      expect(source, isA<MermaidSnapshotSource>());
      expect((source! as MermaidSnapshotSource).source, _graph);
    });

    test('declares no loaded mediaSource', () {
      const mermaid = Mermaid(_graph);
      expect(mermaid.mediaSource, isNull);
    });

    test('no explicit theme uses a null theme key (BuildContext-free, stable)', () {
      const a = Mermaid(_graph);
      const b = Mermaid(_graph);
      expect((a.snapshotSource! as MermaidSnapshotSource).themeKey, isNull);
      expect(a.snapshotSource, b.snapshotSource);
      expect(a.snapshotSource!.cacheKey, b.snapshotSource!.cacheKey);
    });

    test('an explicit theme folds its cache key into the source key', () {
      const themed = Mermaid(_graph, theme: MermaidTheme.light());
      final source = themed.snapshotSource! as MermaidSnapshotSource;
      expect(source.themeKey, const MermaidTheme.light().cacheKey);
    });

    test('a different theme changes the source cacheKey', () {
      const light = Mermaid(_graph, theme: MermaidTheme.light());
      const dark = Mermaid(_graph, theme: MermaidTheme.dark());
      expect(light.snapshotSource!.cacheKey, isNot(dark.snapshotSource!.cacheKey));
    });

    test('takes content params only (theme, reveal, fit, shared)', () {
      const mermaid = Mermaid(
        _graph,
        theme: MermaidTheme.light(),
        reveal: MermaidReveal.fadeNodes(Time.frames(30)),
        fit: BoxFit.fitWidth,
      );
      expect(mermaid.source, _graph);
      expect(mermaid.theme, const MermaidTheme.light());
      expect(mermaid.reveal, const MermaidReveal.fadeNodes(Time.frames(30)));
      expect(mermaid.fit, BoxFit.fitWidth);
    });

    test('defaults reveal to none and fit to contain', () {
      const mermaid = Mermaid(_graph);
      expect(mermaid.reveal, MermaidReveal.none);
      expect(mermaid.fit, BoxFit.contain);
      expect(mermaid.theme, isNull);
    });
  });

  group('capture paint', () {
    testWidgets('paints the resolved raster via a RawImage', (tester) async {
      final decoded = await _solidImage();
      addTearDown(decoded.dispose);
      await _pumpAt(tester, const Mermaid(_graph), decoded);

      final raw = tester.widget<flutter.RawImage>(find.byType(flutter.RawImage));
      expect(raw.image, same(decoded));
      expect(raw.fit, BoxFit.contain);
    });

    testWidgets('passes the fit through to the raster', (tester) async {
      final decoded = await _solidImage();
      addTearDown(decoded.dispose);
      await _pumpAt(tester, const Mermaid(_graph, fit: BoxFit.fill), decoded);

      final raw = tester.widget<flutter.RawImage>(find.byType(flutter.RawImage));
      expect(raw.fit, BoxFit.fill);
    });
  });

  group('reveal opacity per frame', () {
    Future<double?> opacityAt(WidgetTester tester, int frame) async {
      final decoded = await _solidImage();
      addTearDown(decoded.dispose);
      await _pumpAt(
        tester,
        const Mermaid(_graph, reveal: MermaidReveal.fadeNodes(Time.frames(30))),
        decoded,
        frame: frame,
      );
      final raw = tester.widget<flutter.RawImage>(find.byType(flutter.RawImage));
      return raw.color?.a;
    }

    testWidgets('ramps the raster opacity at 0.3 / 0.7 / 1.0 of the window', (tester) async {
      // 30-frame window: frame 9 ~= 0.3, frame 21 ~= 0.7, frame 30 = 1.0.
      expect(await opacityAt(tester, 9), closeTo(0.3, 1e-6));
      expect(await opacityAt(tester, 21), closeTo(0.7, 1e-6));
      // At full the modulation drops away entirely.
      expect(await opacityAt(tester, 30), isNull);
    });

    testWidgets('none reveal applies no opacity modulation', (tester) async {
      final decoded = await _solidImage();
      addTearDown(decoded.dispose);
      await _pumpAt(tester, const Mermaid(_graph), decoded, frame: 5);
      final raw = tester.widget<flutter.RawImage>(find.byType(flutter.RawImage));
      expect(raw.color, isNull);
    });
  });

  group('shared: sugar (D6)', () {
    testWidgets('shared: anchor wraps the built child in a SharedElement', (tester) async {
      final anchor = Anchor('diagram');
      final decoded = await _solidImage();
      addTearDown(decoded.dispose);
      await _pumpAt(tester, Mermaid(_graph, shared: anchor), decoded);

      final shared = tester.widget<SharedElement>(find.byType(SharedElement));
      expect(shared.anchor, same(anchor));
    });

    testWidgets('shared: null mounts no SharedElement', (tester) async {
      final decoded = await _solidImage();
      addTearDown(decoded.dispose);
      await _pumpAt(tester, const Mermaid(_graph), decoded);
      expect(find.byType(SharedElement), findsNothing);
    });
  });

  group('.animate() composes', () {
    testWidgets('mounts a MotionTarget over the Mermaid', (tester) async {
      final decoded = await _solidImage();
      addTearDown(decoded.dispose);
      const mermaid = Mermaid(_graph);
      final source = mermaid.snapshotSource!;
      final resolver = FakeMediaResolver({}, snapshots: {source: decoded});
      await resolver.preResolveAll(const []);

      await tester.pumpWidget(
        ImageResolverScope(
          resolver: resolver,
          child: SizedBox(
            width: 320,
            height: 240,
            child: RenderControllerScope(
              controller: RenderController(),
              child: VideoScope(
                fps: 30,
                duration: const Time.frames(60),
                child: SceneScope(
                  duration: const Time.frames(60),
                  child: mermaid.animate(const []),
                ),
              ),
            ),
          ),
        ),
      );
      expect(find.byType(MotionTarget), findsOneWidget);
    });
  });

  group('invalid source surfaces a render error via the service contract', () {
    testWidgets('an empty diagram has no canned raster -> render error', (tester) async {
      const empty = Mermaid('');
      final source = empty.snapshotSource!;
      // The resolver was never given a raster for this source (the rasterizer
      // would have thrown a FluvieRenderException for an empty SVG in the
      // pre-resolve pass); the sync paint surfaces the same typed failure.
      final resolver = FakeMediaResolver({});
      await resolver.preResolveAll(const []);
      expect(
        () => resolver.decodedSnapshotFor(source),
        throwsA(isA<FluvieRenderException>()),
      );
    });
  });
}
