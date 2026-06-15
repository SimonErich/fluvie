// WI-16 (D-Snapshot): the public Snapshot widget. It captures an arbitrary
// Flutter subtree ONCE before frame 0 (in-process RepaintBoundary.toImage) and
// paints the cached raster every frame — a separate path from the
// SnapshotService/SnapshotSource external pipeline. In preview (no scope) it
// passes the child through live; in capture under a SnapshotCaptureScope holding
// this Snapshot's pre-captured image it paints a RawImage of that image and does
// NOT mount the child; a capture WITHOUT a pre-captured image throws a typed
// FluvieRenderException naming the situation and the pre-pass; shared: wraps a
// SharedElement.

import 'dart:ui' as ui;

import 'package:flutter/widgets.dart' hide Image;
import 'package:flutter/widgets.dart' as flutter;
import 'package:flutter_test/flutter_test.dart';
import 'package:fluvie/src/composition/transition/shared_element.dart';
import 'package:fluvie/src/core/anchor.dart';
import 'package:fluvie/src/core/errors/fluvie_render_exception.dart';
import 'package:fluvie/src/elements/snapshot/runtime/snapshot_capture_scope.dart';
import 'package:fluvie/src/elements/snapshot/snapshot.dart';
import 'package:fluvie/src/rendering/runtime/render_mode.dart';
import 'package:fluvie/src/rendering/runtime/render_mode_context.dart';

Future<ui.Image> _solidImage() async {
  final recorder = ui.PictureRecorder();
  ui.Canvas(recorder).drawRect(
    const ui.Rect.fromLTWH(0, 0, 4, 4),
    ui.Paint()..color = const ui.Color(0xFFE74C3C),
  );
  return recorder.endRecording().toImage(4, 4);
}

class _Marker extends StatelessWidget {
  const _Marker();

  @override
  Widget build(BuildContext context) => const SizedBox(width: 10, height: 10);
}

void main() {
  group('preview (no capture scope)', () {
    testWidgets('passes the child through live', (tester) async {
      await tester.pumpWidget(
        const Directionality(
          textDirection: TextDirection.ltr,
          child: Snapshot(child: _Marker()),
        ),
      );
      expect(find.byType(_Marker), findsOneWidget);
      expect(find.byType(flutter.RawImage), findsNothing);
    });

    testWidgets('passes the child through live in an explicit preview mode', (tester) async {
      // A preview RenderModeContext with no SnapshotCaptureScope above: the
      // running app shows the real subtree, only a capture freezes it.
      await tester.pumpWidget(
        const Directionality(
          textDirection: TextDirection.ltr,
          child: RenderModeContext(
            mode: RenderMode.preview,
            child: Snapshot(child: _Marker()),
          ),
        ),
      );
      expect(find.byType(_Marker), findsOneWidget);
      expect(find.byType(flutter.RawImage), findsNothing);
    });
  });

  group('capture without a capture scope (the unwired pre-pass)', () {
    testWidgets('throws a typed FluvieRenderException naming the pre-pass', (tester) async {
      // No SnapshotCaptureScope above but the mode is capture: the render shell
      // never mounted the Snapshot pre-pass, so painting the live child every
      // frame would silently violate the determinism contract. Fail loud.
      await tester.pumpWidget(
        const Directionality(
          textDirection: TextDirection.ltr,
          child: RenderModeContext(
            mode: RenderMode.capture,
            child: Snapshot(child: _Marker()),
          ),
        ),
      );
      final error = tester.takeException();
      expect(error, isA<FluvieRenderException>());
      final message = (error as FluvieRenderException).message;
      expect(message, contains('Snapshot'));
      expect(message, contains('pre-pass'));
      // The live child must never be mounted in capture.
      expect(find.byType(_Marker), findsNothing);
    });
  });

  group('capture paint (scope with a pre-captured image)', () {
    testWidgets('paints a RawImage of the cached image and does NOT mount the child', (
      tester,
    ) async {
      final image = await _solidImage();
      addTearDown(image.dispose);
      await tester.pumpWidget(
        SnapshotCaptureScope(
          images: {const SnapshotCaptureKey.index(0): image},
          child: const RenderModeContext(
            mode: RenderMode.capture,
            child: Snapshot(child: _Marker()),
          ),
        ),
      );

      final raw = tester.widget<flutter.RawImage>(find.byType(flutter.RawImage));
      expect(raw.image, same(image));
      expect(find.byType(_Marker), findsNothing);
    });

    testWidgets('passes the fit through to the RawImage', (tester) async {
      final image = await _solidImage();
      addTearDown(image.dispose);
      await tester.pumpWidget(
        SnapshotCaptureScope(
          images: {const SnapshotCaptureKey.index(0): image},
          child: const RenderModeContext(
            mode: RenderMode.capture,
            child: Snapshot(fit: BoxFit.fill, child: _Marker()),
          ),
        ),
      );
      final raw = tester.widget<flutter.RawImage>(find.byType(flutter.RawImage));
      expect(raw.fit, BoxFit.fill);
    });

    testWidgets('defaults fit to contain', (tester) async {
      final image = await _solidImage();
      addTearDown(image.dispose);
      await tester.pumpWidget(
        SnapshotCaptureScope(
          images: {const SnapshotCaptureKey.index(0): image},
          child: const RenderModeContext(
            mode: RenderMode.capture,
            child: Snapshot(child: _Marker()),
          ),
        ),
      );
      final raw = tester.widget<flutter.RawImage>(find.byType(flutter.RawImage));
      expect(raw.fit, BoxFit.contain);
    });

    testWidgets('resolves a keyed Snapshot by its widget Key', (tester) async {
      final image = await _solidImage();
      addTearDown(image.dispose);
      await tester.pumpWidget(
        SnapshotCaptureScope(
          images: {const SnapshotCaptureKey.keyed(ValueKey('hero')): image},
          child: const RenderModeContext(
            mode: RenderMode.capture,
            child: Snapshot(key: ValueKey('hero'), child: _Marker()),
          ),
        ),
      );
      final raw = tester.widget<flutter.RawImage>(find.byType(flutter.RawImage));
      expect(raw.image, same(image));
    });

    testWidgets('unkeyed Snapshots resolve by stable build-order index', (tester) async {
      final first = await _solidImage();
      final second = await _solidImage();
      addTearDown(first.dispose);
      addTearDown(second.dispose);
      await tester.pumpWidget(
        SnapshotCaptureScope(
          images: {
            const SnapshotCaptureKey.index(0): first,
            const SnapshotCaptureKey.index(1): second,
          },
          child: const RenderModeContext(
            mode: RenderMode.capture,
            child: Directionality(
              textDirection: TextDirection.ltr,
              child: Column(
                children: [
                  SizedBox(width: 40, height: 40, child: Snapshot(child: _Marker())),
                  SizedBox(width: 40, height: 40, child: Snapshot(child: _Marker())),
                ],
              ),
            ),
          ),
        ),
      );
      final raws = tester.widgetList<flutter.RawImage>(find.byType(flutter.RawImage)).toList();
      expect(raws, hasLength(2));
      expect(raws[0].image, same(first));
      expect(raws[1].image, same(second));
    });
  });

  group('capture without a pre-captured image', () {
    testWidgets('throws a typed FluvieRenderException naming the pre-pass', (tester) async {
      await tester.pumpWidget(
        SnapshotCaptureScope(
          images: const {},
          child: const RenderModeContext(
            mode: RenderMode.capture,
            child: Snapshot(child: _Marker()),
          ),
        ),
      );
      final error = tester.takeException();
      expect(error, isA<FluvieRenderException>());
      final message = (error as FluvieRenderException).message;
      expect(message, contains('Snapshot'));
      expect(message, contains('pre-pass'));
    });

    testWidgets('a capture with a scope but a missing key throws', (tester) async {
      final image = await _solidImage();
      addTearDown(image.dispose);
      // The scope only knows index 0; the second unkeyed Snapshot (index 1) has
      // no captured image.
      await tester.pumpWidget(
        SnapshotCaptureScope(
          images: {const SnapshotCaptureKey.index(0): image},
          child: const RenderModeContext(
            mode: RenderMode.capture,
            child: Directionality(
              textDirection: TextDirection.ltr,
              child: Column(
                children: [
                  SizedBox(width: 40, height: 40, child: Snapshot(child: _Marker())),
                  SizedBox(width: 40, height: 40, child: Snapshot(child: _Marker())),
                ],
              ),
            ),
          ),
        ),
      );
      expect(tester.takeException(), isA<FluvieRenderException>());
    });
  });

  group('shared: sugar (D6)', () {
    testWidgets('shared: anchor wraps the built child in a SharedElement', (tester) async {
      final image = await _solidImage();
      addTearDown(image.dispose);
      final anchor = Anchor('snap');
      await tester.pumpWidget(
        SnapshotCaptureScope(
          images: {const SnapshotCaptureKey.index(0): image},
          child: RenderModeContext(
            mode: RenderMode.capture,
            child: Snapshot(shared: anchor, child: const _Marker()),
          ),
        ),
      );
      final shared = tester.widget<SharedElement>(find.byType(SharedElement));
      expect(shared.anchor, same(anchor));
    });

    testWidgets('shared: null mounts no SharedElement', (tester) async {
      final image = await _solidImage();
      addTearDown(image.dispose);
      await tester.pumpWidget(
        SnapshotCaptureScope(
          images: {const SnapshotCaptureKey.index(0): image},
          child: const RenderModeContext(
            mode: RenderMode.capture,
            child: Snapshot(child: _Marker()),
          ),
        ),
      );
      expect(find.byType(SharedElement), findsNothing);
    });
  });

  group('content params', () {
    test('exposes child, fit and shared, defaulting fit to contain', () {
      const child = _Marker();
      const snapshot = Snapshot(child: child);
      expect(snapshot.child, same(child));
      expect(snapshot.fit, BoxFit.contain);
      expect(snapshot.shared, isNull);
    });
  });
}
