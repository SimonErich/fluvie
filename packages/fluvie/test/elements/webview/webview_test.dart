// WI-14 (D-WebHtml, §15): the public WebView and Html widgets. Each exposes a
// SnapshotSource via MediaCarrier (BuildContext-free, so the collector can read
// it); mounted under a 30fps capture scope with a fake resolver it paints the
// resolved raster through ResolvedSnapshot; scroll/clip change the source
// cacheKey; a String and an equivalent Uri yield the same source; an
// unparseable uri throws ArgumentError; they take content params only; shared:
// wraps a SharedElement.

import 'dart:ui' as ui;

import 'package:flutter/widgets.dart' hide Animation, Image;
import 'package:flutter/widgets.dart' as flutter;
import 'package:flutter_test/flutter_test.dart';
import 'package:fluvie/src/animation/animate_extension.dart';
import 'package:fluvie/src/animation/motion_target.dart';
import 'package:fluvie/src/composition/transition/shared_element.dart';
import 'package:fluvie/src/core/anchor.dart';
import 'package:fluvie/src/core/media/media_carrier.dart';
import 'package:fluvie/src/core/media/snapshot_source.dart';
import 'package:fluvie/src/core/snapshot/snapshot_viewport.dart';
import 'package:fluvie/src/core/time.dart';
import 'package:fluvie/src/elements/webview/html.dart';
import 'package:fluvie/src/elements/webview/webview.dart';
import 'package:fluvie/src/media/runtime/image_resolver_scope.dart';
import 'package:fluvie/src/rendering/runtime/render_controller.dart';
import 'package:fluvie/src/rendering/runtime/render_controller_scope.dart';
import 'package:fluvie/src/rendering/runtime/render_mode.dart';
import 'package:fluvie/src/rendering/runtime/render_mode_context.dart';
import 'package:fluvie/src/timing/scene_scope.dart';
import 'package:fluvie/src/timing/video_scope.dart';

import '../../rendering/fakes/fake_media_resolver.dart';

const _viewport = SnapshotViewport(width: 320, height: 240);
const _url = 'https://example.com/page';
const _html = '<html><body><h1>Hi</h1></body></html>';

Future<ui.Image> _solidImage() async {
  final recorder = ui.PictureRecorder();
  ui.Canvas(recorder).drawRect(
    const ui.Rect.fromLTWH(0, 0, 4, 4),
    ui.Paint()..color = const ui.Color(0xFF3498DB),
  );
  return recorder.endRecording().toImage(4, 4);
}

/// Mounts [carrier] under a 30fps capture scope with a resolver that has
/// [image] canned for the carrier's snapshot source.
Future<void> _pump(WidgetTester tester, MediaCarrier carrier, ui.Image image) async {
  final source = carrier.snapshotSource!;
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
            controller: RenderController(),
            child: VideoScope(
              fps: 30,
              duration: const Time.frames(60),
              child: SceneScope(
                duration: const Time.frames(60),
                child: carrier as Widget,
              ),
            ),
          ),
        ),
      ),
    ),
  );
}

void main() {
  group('WebView.url as a MediaCarrier', () {
    test('exposes a UrlSnapshotSource carrying host, viewport, scroll and clip', () {
      final view = WebView.url(
        _url,
        viewport: _viewport,
        scroll: const Offset(10, 20),
        clip: const Rect.fromLTWH(0, 0, 100, 80),
      );
      expect(view, isA<MediaCarrier>());
      final source = view.snapshotSource;
      expect(source, isA<UrlSnapshotSource>());
      final url = source! as UrlSnapshotSource;
      expect(url.host, 'example.com');
      expect(url.viewport, _viewport);
      expect(url.scrollX, 10);
      expect(url.scrollY, 20);
      expect(url.clipWidth, 100);
      expect(url.clipHeight, 80);
    });

    test('declares no loaded mediaSource', () {
      final view = WebView.url(_url, viewport: _viewport);
      expect(view.mediaSource, isNull);
    });

    test('a String and an equivalent Uri yield the same source', () {
      final fromUri = WebView.url(Uri.parse(_url), viewport: _viewport);
      final fromString = WebView.url(_url, viewport: _viewport);
      expect(fromUri.snapshotSource, fromString.snapshotSource);
      expect(fromUri.snapshotSource!.cacheKey, fromString.snapshotSource!.cacheKey);
    });

    test('scroll changes the source cacheKey', () {
      final a = WebView.url(_url, viewport: _viewport);
      final b = WebView.url(_url, viewport: _viewport, scroll: const Offset(0, 40));
      expect(a.snapshotSource!.cacheKey, isNot(b.snapshotSource!.cacheKey));
    });

    test('clip changes the source cacheKey', () {
      final a = WebView.url(_url, viewport: _viewport);
      final b = WebView.url(_url, viewport: _viewport, clip: const Rect.fromLTWH(0, 0, 50, 50));
      expect(a.snapshotSource!.cacheKey, isNot(b.snapshotSource!.cacheKey));
    });

    test('an unparseable uri throws ArgumentError', () {
      expect(() => WebView.url('::not a uri::', viewport: _viewport), throwsArgumentError);
    });

    test('a non-String, non-Uri argument throws ArgumentError', () {
      expect(() => WebView.url(42, viewport: _viewport), throwsArgumentError);
    });

    test('takes content params only (viewport, scroll, clip, fit, shared)', () {
      final view = WebView.url(
        _url,
        viewport: _viewport,
        scroll: const Offset(5, 6),
        clip: const Rect.fromLTWH(0, 0, 30, 30),
        fit: BoxFit.contain,
      );
      expect(view.fit, BoxFit.contain);
    });

    test('defaults fit to cover and scroll/clip to none', () {
      final view = WebView.url(_url, viewport: _viewport);
      expect(view.fit, BoxFit.cover);
      final source = view.snapshotSource! as UrlSnapshotSource;
      expect(source.scrollX, 0);
      expect(source.scrollY, 0);
      expect(source.clipWidth, isNull);
      expect(source.clipHeight, isNull);
    });
  });

  group('Html as a MediaCarrier', () {
    test('exposes an HtmlSnapshotSource carrying source and viewport', () {
      const html = Html(_html, viewport: _viewport);
      expect(html, isA<MediaCarrier>());
      final source = html.snapshotSource;
      expect(source, isA<HtmlSnapshotSource>());
      final h = source! as HtmlSnapshotSource;
      expect(h.source, _html);
      expect(h.viewport, _viewport);
    });

    test('declares no loaded mediaSource', () {
      const html = Html(_html, viewport: _viewport);
      expect(html.mediaSource, isNull);
    });

    test('the html source and viewport fold into the cache key', () {
      const a = Html(_html, viewport: _viewport);
      const b = Html('<p>other</p>', viewport: _viewport);
      const c = Html(_html, viewport: SnapshotViewport(width: 100, height: 100));
      expect(a.snapshotSource!.cacheKey, isNot(b.snapshotSource!.cacheKey));
      expect(a.snapshotSource!.cacheKey, isNot(c.snapshotSource!.cacheKey));
    });

    test('defaults fit to cover', () {
      const html = Html(_html, viewport: _viewport);
      expect(html.fit, BoxFit.cover);
    });
  });

  group('capture paint', () {
    testWidgets('WebView paints the resolved raster via a RawImage at the fit', (tester) async {
      final decoded = await _solidImage();
      addTearDown(decoded.dispose);
      await _pump(tester, WebView.url(_url, viewport: _viewport), decoded);

      final raw = tester.widget<flutter.RawImage>(find.byType(flutter.RawImage));
      expect(raw.image, same(decoded));
      expect(raw.fit, BoxFit.cover);
    });

    testWidgets('Html paints the resolved raster via a RawImage', (tester) async {
      final decoded = await _solidImage();
      addTearDown(decoded.dispose);
      await _pump(tester, const Html(_html, viewport: _viewport), decoded);

      final raw = tester.widget<flutter.RawImage>(find.byType(flutter.RawImage));
      expect(raw.image, same(decoded));
    });

    testWidgets('WebView passes a custom fit through', (tester) async {
      final decoded = await _solidImage();
      addTearDown(decoded.dispose);
      await _pump(
        tester,
        WebView.url(_url, viewport: _viewport, fit: BoxFit.fill),
        decoded,
      );
      final raw = tester.widget<flutter.RawImage>(find.byType(flutter.RawImage));
      expect(raw.fit, BoxFit.fill);
    });
  });

  group('shared: sugar (D6)', () {
    testWidgets('WebView shared: anchor wraps the built child in a SharedElement', (tester) async {
      final anchor = Anchor('page');
      final decoded = await _solidImage();
      addTearDown(decoded.dispose);
      await _pump(tester, WebView.url(_url, viewport: _viewport, shared: anchor), decoded);

      final shared = tester.widget<SharedElement>(find.byType(SharedElement));
      expect(shared.anchor, same(anchor));
    });

    testWidgets('Html shared: anchor wraps the built child in a SharedElement', (tester) async {
      final anchor = Anchor('doc');
      final decoded = await _solidImage();
      addTearDown(decoded.dispose);
      await _pump(tester, Html(_html, viewport: _viewport, shared: anchor), decoded);

      final shared = tester.widget<SharedElement>(find.byType(SharedElement));
      expect(shared.anchor, same(anchor));
    });

    testWidgets('shared: null mounts no SharedElement', (tester) async {
      final decoded = await _solidImage();
      addTearDown(decoded.dispose);
      await _pump(tester, WebView.url(_url, viewport: _viewport), decoded);
      expect(find.byType(SharedElement), findsNothing);
    });
  });

  group('.animate() composes', () {
    testWidgets('mounts a MotionTarget over the WebView', (tester) async {
      final decoded = await _solidImage();
      addTearDown(decoded.dispose);
      final view = WebView.url(_url, viewport: _viewport);
      final source = view.snapshotSource!;
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
                  child: view.animate(const []),
                ),
              ),
            ),
          ),
        ),
      );
      expect(find.byType(MotionTarget), findsOneWidget);
    });
  });
}
