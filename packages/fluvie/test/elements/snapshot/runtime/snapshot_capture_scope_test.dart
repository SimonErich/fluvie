// WI-16 (D-Snapshot): the capture scope for Snapshot subtrees. It carries a
// map of capture-key -> ui.Image (the pre-captured rasters) and a stable order
// cursor so unkeyed Snapshots resolve the same index in the pre-pass and the
// frame loop. captureSnapshotChildren rasterizes a set of children exactly once
// via the existing toImage primitive and returns the key->image map.

import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:fluvie/src/elements/snapshot/runtime/snapshot_capture.dart';
import 'package:fluvie/src/elements/snapshot/runtime/snapshot_capture_scope.dart';

void _setView(WidgetTester tester, double width, double height) {
  tester.view.physicalSize = ui.Size(width, height);
  tester.view.devicePixelRatio = 1.0;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
}

Future<ui.Image> _solidImage([int color = 0xFF2ECC71]) async {
  final recorder = ui.PictureRecorder();
  ui.Canvas(recorder).drawRect(
    const ui.Rect.fromLTWH(0, 0, 4, 4),
    ui.Paint()..color = ui.Color(color),
  );
  return recorder.endRecording().toImage(4, 4);
}

void main() {
  group('SnapshotCaptureKey', () {
    test('keyed keys are value-equal by their widget Key', () {
      // Distinct ValueKey instances built from a runtime-joined string, so
      // equality is genuine value equality (not const canonicalization to one
      // identity).
      final label = ['lo', 'go'].join();
      final a = SnapshotCaptureKey.keyed(ValueKey(label));
      final b = SnapshotCaptureKey.keyed(ValueKey(label));
      expect(identical(a, b), isFalse);
      expect(a, b);
      expect(a.hashCode, b.hashCode);
    });

    test('different widget keys produce distinct capture keys', () {
      expect(
        const SnapshotCaptureKey.keyed(ValueKey('a')),
        isNot(const SnapshotCaptureKey.keyed(ValueKey('b'))),
      );
    });

    test('index keys are value-equal by their index', () {
      expect(const SnapshotCaptureKey.index(2), const SnapshotCaptureKey.index(2));
      expect(const SnapshotCaptureKey.index(2), isNot(const SnapshotCaptureKey.index(3)));
    });

    test('a keyed key and an index key never collide', () {
      expect(
        const SnapshotCaptureKey.keyed(ValueKey(0)),
        isNot(const SnapshotCaptureKey.index(0)),
      );
    });
  });

  group('SnapshotCaptureScope.maybeOf', () {
    testWidgets('returns null when there is no scope above', (tester) async {
      late BuildContext captured;
      await tester.pumpWidget(
        Builder(
          builder: (context) {
            captured = context;
            return const SizedBox();
          },
        ),
      );
      expect(SnapshotCaptureScope.maybeOf(captured), isNull);
    });

    testWidgets('returns the nearest scope above', (tester) async {
      final image = await _solidImage();
      addTearDown(image.dispose);
      late SnapshotCaptureScope? scope;
      await tester.pumpWidget(
        SnapshotCaptureScope(
          images: {const SnapshotCaptureKey.index(0): image},
          child: Builder(
            builder: (context) {
              scope = SnapshotCaptureScope.maybeOf(context);
              return const SizedBox();
            },
          ),
        ),
      );
      expect(scope, isNotNull);
      expect(scope!.images, hasLength(1));
    });
  });

  group('SnapshotCaptureScope order cursor', () {
    testWidgets('hands out a stable monotonic index in build order', (tester) async {
      final image = await _solidImage();
      addTearDown(image.dispose);
      final indices = <int>[];
      Widget probe() => Builder(
        builder: (context) {
          indices.add(SnapshotCaptureScope.of(context).nextOrderIndex());
          return const SizedBox();
        },
      );
      await tester.pumpWidget(
        SnapshotCaptureScope(
          images: {const SnapshotCaptureKey.index(0): image},
          child: Column(children: [probe(), probe(), probe()]),
        ),
      );
      expect(indices, [0, 1, 2]);
    });

    testWidgets('a fresh scope per pump yields stable indices', (tester) async {
      // The render shell mounts a fresh SnapshotCaptureScope (fresh cursor)
      // carrying the same images each frame; copyWithChild models that. Each
      // pump starts the cursor at 0, so the n-th unkeyed Snapshot is index n
      // every frame regardless of how many frames render.
      final image = await _solidImage();
      addTearDown(image.dispose);
      final indices = <int>[];
      Widget probe() => Builder(
        builder: (context) {
          indices.add(SnapshotCaptureScope.of(context).nextOrderIndex());
          return const SizedBox();
        },
      );
      final images = {const SnapshotCaptureKey.index(0): image};
      for (var frame = 0; frame < 3; frame++) {
        indices.clear();
        await tester.pumpWidget(
          SnapshotCaptureScope(
            images: images,
            child: Column(children: [probe(), probe()]),
          ),
        );
        expect(indices, [0, 1], reason: 'frame $frame must restart the cursor at 0');
      }
    });

    testWidgets('resetCursor makes same-instance re-pump stable (the frame-loop case)', (
      tester,
    ) async {
      // The harness pumps ONE persistent tree and re-pumps it per frame via
      // tester.pump(); the SAME scope instance is read every frame. Without a
      // per-frame reset the cursor drifts (0,1 then 2,3 then 4,5 ...). The shell
      // calls resetCursor() before each frame's pump to keep indices stable.
      final image = await _solidImage();
      addTearDown(image.dispose);
      final indices = <int>[];
      final notifier = ValueNotifier<int>(0);
      addTearDown(notifier.dispose);
      Widget probe() => Builder(
        builder: (context) {
          indices.add(SnapshotCaptureScope.of(context).nextOrderIndex());
          return const SizedBox();
        },
      );
      final scope = SnapshotCaptureScope(
        images: {const SnapshotCaptureKey.index(0): image},
        // The probes rebuild every frame because they depend on the notifier
        // below the scope, exactly like Snapshots depend on the render clock.
        child: ValueListenableBuilder<int>(
          valueListenable: notifier,
          builder: (_, _, _) => Column(children: [probe(), probe()]),
        ),
      );
      await tester.pumpWidget(scope);
      expect(indices, [0, 1]);
      for (var frame = 1; frame < 3; frame++) {
        indices.clear();
        scope.resetCursor();
        notifier.value = frame;
        await tester.pump();
        expect(indices, [0, 1], reason: 'frame $frame must restart the cursor at 0');
      }
    });

    testWidgets('of throws a FlutterError when no scope is above', (tester) async {
      late BuildContext captured;
      await tester.pumpWidget(
        Builder(
          builder: (context) {
            captured = context;
            return const SizedBox();
          },
        ),
      );
      expect(() => SnapshotCaptureScope.of(captured), throwsA(isA<FlutterError>()));
    });
  });

  group('captureSnapshotChildren / captureBoundaryImage', () {
    SnapshotPump pumpVia(WidgetTester tester) =>
        (boundaryKey, child) => tester.pumpWidget(
          Directionality(
            textDirection: TextDirection.ltr,
            child: RepaintBoundary(key: boundaryKey, child: child),
          ),
        );

    testWidgets('captures keyed and unkeyed children exactly once each', (tester) async {
      _setView(tester, 64, 64);
      late Map<SnapshotCaptureKey, ui.Image> images;
      await tester.runAsync(() async {
        images = await captureSnapshotChildren(
          pump: pumpVia(tester),
          keyed: {
            const ValueKey('logo'): const ColoredBox(color: Color(0xFF112233)),
          },
          unkeyed: const [ColoredBox(color: Color(0xFF445566))],
        );
      });
      expect(images.keys, contains(const SnapshotCaptureKey.keyed(ValueKey('logo'))));
      expect(images.keys, contains(const SnapshotCaptureKey.index(0)));
      expect(images, hasLength(2));
      for (final image in images.values) {
        expect(image.width, 64);
        expect(image.height, 64);
        addTearDown(image.dispose);
      }
    });

    testWidgets('the same child rasterizes to identical bytes twice (determinism)', (tester) async {
      _setView(tester, 64, 64);
      Future<Uint8List> bytesOnce() async {
        late Uint8List bytes;
        await tester.runAsync(() async {
          final images = await captureSnapshotChildren(
            pump: pumpVia(tester),
            keyed: const {},
            unkeyed: [const ColoredBox(color: Color(0xFF8E44AD))],
          );
          final image = images[const SnapshotCaptureKey.index(0)]!;
          final data = await image.toByteData();
          bytes = data!.buffer.asUint8List(data.offsetInBytes, data.lengthInBytes);
          image.dispose();
        });
        return bytes;
      }

      final first = await bytesOnce();
      final second = await bytesOnce();
      expect(first, second);
    });

    testWidgets('captureBoundaryImage throws when the key is not mounted', (tester) async {
      await tester.pumpWidget(const SizedBox());
      final unmounted = GlobalKey();
      expect(() => captureBoundaryImage(unmounted), throwsA(isA<FlutterError>()));
    });

    testWidgets('captureBoundaryImage throws when the key is not a RepaintBoundary', (
      tester,
    ) async {
      final key = GlobalKey();
      await tester.pumpWidget(SizedBox(key: key));
      expect(() => captureBoundaryImage(key), throwsA(isA<FlutterError>()));
    });
  });
}
