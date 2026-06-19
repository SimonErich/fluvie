// P12-SNAP wiring (D-Snapshot): the in-process Snapshot subtree-capture path,
// proven through the real render-shell pre-pass — not just the WI-16 unit fake.
//
// The earlier suite mounted a hand-built SnapshotCaptureScope; nothing wired the
// pre-pass into the capture shell, so a real capture found no scope and (before
// the fix) rendered the live child every frame — a silent determinism violation.
// This drives the actual harness pre-pass and proves:
//   (a) the inner Image is decoded BEFORE the Snapshot subtree is rasterized,
//   (b) the Snapshot paints the cached still (a RawImage), not the live child,
//   (c) two capture runs of the same subtree produce byte-identical rasters.

import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart' hide Animation, Image;
import 'package:flutter/widgets.dart' as flutter;
import 'package:flutter_test/flutter_test.dart';
import 'package:fluvie/fluvie.dart';
import 'package:fluvie/src/elements/snapshot/runtime/snapshot_capture.dart';
import 'package:fluvie/src/elements/snapshot/runtime/snapshot_capture_scope.dart';
import 'package:fluvie/src/media/media_bytes_loader.dart';
import 'package:fluvie/src/media/media_repository.dart';
import 'package:fluvie/src/media/net/media_http_client.dart';
import 'package:fluvie/src/media/net/network_allowlist.dart';
import 'package:fluvie/src/media/runtime/image_resolver_scope.dart';
import 'package:fluvie_example/render/composition_entry.dart';

import 'harness_snapshot.dart';
import 'render_harness.dart';

const _swatch = MediaSource.asset('assets/fixtures/swatch.png');

/// A Snapshot whose child paints an Image: the headline ordering case (the inner
/// media must be decoded before the subtree rasterizes).
Snapshot _snapshotWithImage() => Snapshot(child: Image.asset('assets/fixtures/swatch.png'));

/// A repository over the committed swatch fixture using the real decode path.
MediaRepository _repository() => MediaRepository(
  loader: MediaBytesLoader(
    bundle: rootBundle,
    httpClient: _NoHttp(),
    allowlist: NetworkAllowlist.allowAny(),
  ),
);

void _setView(WidgetTester tester) {
  tester.view.physicalSize = const ui.Size(32, 32);
  tester.view.devicePixelRatio = 1.0;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
}

void main() {
  testWidgets('the inner Image is decoded before the Snapshot subtree rasterizes', (tester) async {
    _setView(tester);
    final repo = _repository();
    await tester.runAsync(() async {
      // The shell collects the Snapshot's inner media and pre-resolves it FIRST,
      // exactly as prepareEntryMedia does (Snapshot implements CollectibleChildren
      // so collectMediaSources descends into its child).
      final scenes = [
        Scene(duration: const Time.seconds(1), children: [_snapshotWithImage()]),
      ];
      final media = collectMediaSources(scenes);
      expect(media, {_swatch}, reason: 'the Snapshot child media is collected');
      await repo.preResolveAll(media);

      // Decoded BEFORE we rasterize: a synchronous lookup must already succeed.
      final decoded = repo.decodedImageFor(_swatch);
      expect(decoded, isA<ui.Image>());

      // Now the pre-pass rasterizes the Snapshot child UNDER the resolver, so the
      // inner Image paints from the decoded cache during toImage (no async pop-in).
      final snapshots = collectSnapshots(scenes);
      final images = await captureSnapshotChildren(
        pump: _resolvedPump(tester, repo),
        keyed: const {},
        unkeyed: [for (final s in snapshots) s.child],
      );
      expect(images, hasLength(1));
      addTearDown(images.values.single.dispose);
    });
  });

  testWidgets('the Snapshot paints the cached still (RawImage), not the live child', (
    tester,
  ) async {
    _setView(tester);
    final repo = _repository();
    await tester.runAsync(() async {
      final scene = Scene(duration: const Time.seconds(1), children: [_snapshotWithImage()]);
      await repo.preResolveAll(collectMediaSources([scene]));
      final snapshots = collectSnapshots([scene]);
      final captured = await captureSnapshotChildren(
        pump: _resolvedPump(tester, repo),
        keyed: const {},
        unkeyed: [for (final s in snapshots) s.child],
      );
      final scope = SnapshotCaptureScope(images: captured);
      addTearDown(() {
        for (final image in captured.values) {
          image.dispose();
        }
      });

      // Mount the composition under the scope ABOVE it, in capture mode.
      await tester.pumpWidget(
        scope.copyWithChild(
          RenderModeContext(
            mode: RenderMode.capture,
            child: Directionality(
              textDirection: TextDirection.ltr,
              child: Snapshot(child: Image.asset('fixtures/swatch.png')),
            ),
          ),
        ),
      );

      // The frame loop paints the cached still: a RawImage holding the captured
      // ui.Image, and the live Image element is never mounted.
      final raw = tester.widget<flutter.RawImage>(find.byType(flutter.RawImage));
      expect(raw.image, same(captured[const SnapshotCaptureKey.index(0)]));
      expect(find.byType(Image), findsNothing, reason: 'the live child must not mount in capture');
    });
  });

  testWidgets('two capture runs of the same subtree produce byte-identical rasters', (
    tester,
  ) async {
    _setView(tester);
    Future<Uint8List> rasterOnce() async {
      final repo = _repository();
      late Uint8List bytes;
      await tester.runAsync(() async {
        final scene = Scene(duration: const Time.seconds(1), children: [_snapshotWithImage()]);
        await repo.preResolveAll(collectMediaSources([scene]));
        final snapshots = collectSnapshots([scene]);
        final captured = await captureSnapshotChildren(
          pump: _resolvedPump(tester, repo),
          keyed: const {},
          unkeyed: [for (final s in snapshots) s.child],
        );
        final image = captured[const SnapshotCaptureKey.index(0)]!;
        final data = await image.toByteData();
        bytes = data!.buffer.asUint8List(data.offsetInBytes, data.lengthInBytes);
        image.dispose();
      });
      return bytes;
    }

    final first = await rasterOnce();
    final second = await rasterOnce();
    expect(first, second, reason: 'identical subtree -> byte-identical raster (determinism)');
  });

  testWidgets('runCaptureHarness wires the pre-pass: no live child, throws nowhere', (
    tester,
  ) async {
    // The headline regression guard: a composition with a Snapshot rendered
    // through the real harness mounts the scope, so no FluvieRenderException is
    // raised mid-render and the live Image child is never re-rasterized.
    _setView(tester);
    final scope = await captureSnapshotScopeForScenes(
      tester: tester,
      scenes: [
        Scene(duration: const Time.seconds(1), children: [_snapshotWithImage()]),
      ],
      resolver: await _resolved(tester),
      width: 32,
      height: 32,
    );
    expect(scope, isNotNull);
    expect(scope!.imageFor(const SnapshotCaptureKey.index(0)), isA<ui.Image>());
    addTearDown(() {
      for (final image in scope.images.values) {
        image.dispose();
      }
    });
  });

  testWidgets('runCaptureHarness renders a Snapshot over many frames without drift', (
    tester,
  ) async {
    // The full shell path: a Snapshot composition rendered through
    // runCaptureHarness. The pre-pass mounts the scope and the per-frame cursor
    // reset keeps the unkeyed index stable, so no frame throws on a missing
    // raster mid-render. Two unkeyed Snapshots stress the order cursor.
    final outDir = Directory.systemTemp.createTempSync('fluvie_snap_e2e_');
    addTearDown(() => outDir.deleteSync(recursive: true));

    const entry = CompositionEntry(
      key: 'snapshot_probe',
      width: 32,
      height: 32,
      fps: 30,
      frameCount: 6,
      build: _buildSnapshotComposition,
    );

    // No FluvieRenderException is thrown across the 6-frame loop: the scope is
    // mounted and the cursor restarts at 0 every frame (drift would throw).
    final manifest = await runCaptureHarness(
      tester: tester,
      entry: entry,
      outDir: outDir,
      cacheEnabled: false,
      prepareMedia: (_) async => null,
      snapshotScenes: (_) => _snapshotProbeScenes(),
    );
    expect(manifest.frameCount, 6);
    expect(File('${outDir.path}/frames.rgba').lengthSync(), 6 * 32 * 32 * 4);
  });
}

/// Two unkeyed Snapshots so the order cursor is exercised across frames; each is
/// boxed to fit the small probe canvas without overflowing the column, and each
/// is `.animate()`d so the Snapshot rebuilds EVERY frame — the realistic case
/// where a non-reset cursor would drift (frame 2's first index would be 2, not
/// 0) and throw on a missing raster mid-render.
List<Scene> _snapshotProbeScenes() => [
  Scene(
    duration: const Time.frames(6),
    children: [
      Column(
        children: [
          SizedBox(
            width: 16,
            height: 16,
            child: const Snapshot(
              child: ColoredBox(color: Color(0xFF112233)),
            ).animate([Animation.fadeIn()]),
          ),
          SizedBox(
            width: 16,
            height: 16,
            child: const Snapshot(
              child: ColoredBox(color: Color(0xFF445566)),
            ).animate([Animation.fadeIn()]),
          ),
        ],
      ),
    ],
  ),
];

/// The renderable composition mirroring [_snapshotProbeScenes]; the harness
/// mounts this every frame, and the pre-pass froze each Snapshot child.
Widget _buildSnapshotComposition() {
  final video = Video(width: 32, height: 32, scenes: _snapshotProbeScenes());
  return Directionality(textDirection: TextDirection.ltr, child: video);
}

Future<MediaResolver> _resolved(WidgetTester tester) async {
  final repo = _repository();
  await tester.runAsync(() async {
    await repo.preResolveAll({_swatch});
  });
  return repo;
}

/// A [SnapshotPump] that mounts each captured child under the [ImageResolverScope]
/// so the inner Image paints from the decoded cache during the toImage read-back.
SnapshotPump _resolvedPump(WidgetTester tester, MediaResolver resolver) =>
    (boundaryKey, child) => tester.pumpWidget(
      ImageResolverScope(
        resolver: resolver,
        child: Directionality(
          textDirection: TextDirection.ltr,
          child: RepaintBoundary(key: boundaryKey, child: child),
        ),
      ),
    );

class _NoHttp implements MediaHttpClient {
  @override
  Future<Uint8List> get(Uri url) async => throw StateError('no network: $url');
}
