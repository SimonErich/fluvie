// WI-17 (D-DeviceFrame, §15): the public DeviceFrame chrome wrappers. Each named
// factory wraps an arbitrary child with device chrome — .phone a rounded bezel
// (with an optional notch), .browser a top address bar carrying three
// traffic-light dots and an optional url, .tablet a thinner bezel. The chrome is
// pure presentational (NO raster, NO SnapshotService, NOT a MediaCarrier): it
// composes over ANY child (a WebView/Html/Mermaid/Image/plain widget). Chrome
// colors come from context.fluvie (a custom FluvieTokensScope changes them).
// shared: wraps a SharedElement. The DeviceFramePainter is capture-safe.

import 'dart:ui' as ui;

import 'package:flutter/widgets.dart' hide Animation, Image;
import 'package:flutter/widgets.dart' as flutter;
import 'package:flutter_test/flutter_test.dart';
import 'package:fluvie/src/composition/transition/shared_element.dart';
import 'package:fluvie/src/core/anchor.dart';
import 'package:fluvie/src/core/media/media_carrier.dart';
import 'package:fluvie/src/core/snapshot/snapshot_viewport.dart';
import 'package:fluvie/src/elements/snapshot/device_frame.dart';
import 'package:fluvie/src/elements/snapshot/render/device_frame_painter.dart';
import 'package:fluvie/src/elements/webview/html.dart';
import 'package:fluvie/src/media/runtime/image_resolver_scope.dart';
import 'package:fluvie/src/theme/fluvie_tokens.dart';
import 'package:fluvie/src/theme/fluvie_tokens_scope.dart';

import '../../rendering/fakes/fake_media_resolver.dart';

class _Marker extends StatelessWidget {
  const _Marker();

  @override
  Widget build(BuildContext context) => const SizedBox(width: 40, height: 40);
}

Widget _boxed(Widget child) => Directionality(
  textDirection: TextDirection.ltr,
  child: Center(
    child: SizedBox(width: 200, height: 300, child: child),
  ),
);

DeviceFramePainter _painterOf(WidgetTester tester) {
  final paint = tester.widget<CustomPaint>(
    find.descendant(
      of: find.byType(DeviceFrame),
      matching: find.byWidgetPredicate((w) => w is CustomPaint && w.painter is DeviceFramePainter),
    ),
  );
  return paint.painter! as DeviceFramePainter;
}

void main() {
  group('DeviceFrame.phone', () {
    testWidgets('wraps the child with a phone bezel and probes the painter', (tester) async {
      await tester.pumpWidget(_boxed(const DeviceFrame.phone(child: _Marker())));
      expect(find.byType(_Marker), findsOneWidget);
      final painter = _painterOf(tester);
      expect(painter.style, DeviceFrameStyle.phone);
    });

    testWidgets('draws a notch by default and can suppress it', (tester) async {
      await tester.pumpWidget(_boxed(const DeviceFrame.phone(child: _Marker())));
      expect(_painterOf(tester).notch, isTrue);

      await tester.pumpWidget(
        _boxed(const DeviceFrame.phone(notch: false, child: _Marker())),
      );
      expect(_painterOf(tester).notch, isFalse);
    });

    testWidgets('paints no address bar and no url text', (tester) async {
      await tester.pumpWidget(_boxed(const DeviceFrame.phone(child: _Marker())));
      final painter = _painterOf(tester);
      expect(painter.showAddressBar, isFalse);
      expect(painter.url, isNull);
      expect(find.text('https://example.com'), findsNothing);
    });
  });

  group('DeviceFrame.browser', () {
    testWidgets('paints the address bar with three traffic-light dots and the url text', (
      tester,
    ) async {
      await tester.pumpWidget(
        _boxed(const DeviceFrame.browser(url: 'https://example.com', child: _Marker())),
      );
      expect(find.byType(_Marker), findsOneWidget);
      final painter = _painterOf(tester);
      expect(painter.style, DeviceFrameStyle.browser);
      expect(painter.showAddressBar, isTrue);
      expect(painter.dotCount, 3);
      expect(painter.url, 'https://example.com');
      expect(find.text('https://example.com'), findsOneWidget);
    });

    testWidgets('a null url paints the bar with dots but no url text', (tester) async {
      // Built non-const (a runtime Key) so the named-constructor body runs.
      await tester.pumpWidget(
        _boxed(DeviceFrame.browser(key: UniqueKey(), child: const _Marker())),
      );
      final painter = _painterOf(tester);
      expect(painter.showAddressBar, isTrue);
      expect(painter.dotCount, 3);
      expect(painter.url, isNull);
      expect(find.byType(flutter.Text), findsNothing);
    });
  });

  group('DeviceFrame.tablet', () {
    testWidgets('wraps the child with a tablet bezel', (tester) async {
      // Built non-const (a runtime Key) so the named-constructor body runs.
      await tester.pumpWidget(
        _boxed(DeviceFrame.tablet(key: UniqueKey(), child: const _Marker())),
      );
      expect(find.byType(_Marker), findsOneWidget);
      final painter = _painterOf(tester);
      expect(painter.style, DeviceFrameStyle.tablet);
      expect(painter.notch, isFalse);
      expect(painter.showAddressBar, isFalse);
    });
  });

  group('chrome colors come from context.fluvie', () {
    testWidgets('a FluvieTokensScope changes the chrome colors', (tester) async {
      const custom = FluvieTokens(
        palette: ChartPalette([Color(0xFF112233)]),
        axisColor: Color(0xFF445566),
        gridColor: Color(0xFF778899),
        labelColor: Color(0xFFAABBCC),
        code: CodeTheme.light(),
      );
      await tester.pumpWidget(
        FluvieTokensScope(
          tokens: custom,
          child: _boxed(const DeviceFrame.browser(child: _Marker())),
        ),
      );
      final painter = _painterOf(tester);
      expect(painter.chromeColor, const CodeTheme.light().chromeColor);
      expect(painter.bezelColor, const CodeTheme.light().background);
    });

    testWidgets('falls back to the package tokens with no scope', (tester) async {
      await tester.pumpWidget(_boxed(const DeviceFrame.phone(child: _Marker())));
      final painter = _painterOf(tester);
      expect(painter.chromeColor, const FluvieTokens.fallback().code.chromeColor);
    });
  });

  group('composes over a snapshot-backed child', () {
    testWidgets('a DeviceFrame.browser over an Html resolved via a fake resolver renders', (
      tester,
    ) async {
      const viewport = SnapshotViewport(width: 80, height: 60);
      const html = Html('<h1>Hi</h1>', viewport: viewport);
      final decoded = await _solidImage();
      addTearDown(decoded.dispose);
      final resolver = FakeMediaResolver({}, snapshots: {html.snapshotSource!: decoded});
      await resolver.preResolveAll(const []);

      await tester.pumpWidget(
        ImageResolverScope(
          resolver: resolver,
          child: _boxed(
            const DeviceFrame.browser(url: 'https://example.com', child: html),
          ),
        ),
      );

      expect(find.byType(Html), findsOneWidget);
      final raw = tester.widget<flutter.RawImage>(find.byType(flutter.RawImage));
      expect(raw.image, same(decoded));
      // The chrome is painted around the child.
      expect(_painterOf(tester).showAddressBar, isTrue);
    });
  });

  group('content params and shared:', () {
    test('is not a MediaCarrier and exposes only chrome params', () {
      const frame = DeviceFrame.browser(url: 'https://x.test', child: _Marker());
      expect(frame, isNot(isA<MediaCarrier>()));
      expect(frame.url, 'https://x.test');
      expect(frame.style, DeviceFrameStyle.browser);
      expect(frame.shared, isNull);
    });

    testWidgets('shared: anchor wraps the framed child in a SharedElement', (tester) async {
      final anchor = Anchor('device');
      await tester.pumpWidget(
        _boxed(DeviceFrame.phone(shared: anchor, child: const _Marker())),
      );
      final shared = tester.widget<SharedElement>(find.byType(SharedElement));
      expect(shared.anchor, same(anchor));
    });

    testWidgets('shared: null mounts no SharedElement', (tester) async {
      await tester.pumpWidget(_boxed(const DeviceFrame.tablet(child: _Marker())));
      expect(find.byType(SharedElement), findsNothing);
    });
  });

  group('DeviceFramePainter shouldRepaint', () {
    test('repaints when a chrome input changes and not when identical', () {
      const a = DeviceFramePainter(
        style: DeviceFrameStyle.browser,
        bezelColor: Color(0xFF101010),
        chromeColor: Color(0xFF202020),
        urlColor: Color(0xFF303030),
        notch: false,
        showAddressBar: true,
        url: 'https://a.test',
      );
      const same = DeviceFramePainter(
        style: DeviceFrameStyle.browser,
        bezelColor: Color(0xFF101010),
        chromeColor: Color(0xFF202020),
        urlColor: Color(0xFF303030),
        notch: false,
        showAddressBar: true,
        url: 'https://a.test',
      );
      const differentUrl = DeviceFramePainter(
        style: DeviceFrameStyle.browser,
        bezelColor: Color(0xFF101010),
        chromeColor: Color(0xFF202020),
        urlColor: Color(0xFF303030),
        notch: false,
        showAddressBar: true,
        url: 'https://b.test',
      );
      expect(a.shouldRepaint(same), isFalse);
      expect(a.shouldRepaint(differentUrl), isTrue);
    });
  });
}

Future<ui.Image> _solidImage() async {
  final recorder = ui.PictureRecorder();
  ui.Canvas(recorder).drawRect(
    const ui.Rect.fromLTWH(0, 0, 4, 4),
    ui.Paint()..color = const ui.Color(0xFF2ECC71),
  );
  return recorder.endRecording().toImage(4, 4);
}
