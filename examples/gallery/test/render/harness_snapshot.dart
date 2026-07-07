import 'dart:convert';
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/services.dart' show rootBundle;
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:fluvie/fluvie.dart';
import 'package:fluvie/rendering.dart';
// The snapshot media wiring lives under `src/`: pre-resolution is render
// infrastructure, not part of the authoring surface a lesson imports. The
// `SnapshotService` contract itself is public via the barrel.
import 'package:fluvie/src/core/hash/fnv1a.dart';
import 'package:fluvie/src/core/media/snapshot_source.dart';
import 'package:fluvie/src/core/snapshot/snapshot_raster.dart';
import 'package:fluvie/src/core/snapshot/snapshot_request.dart';
import 'package:fluvie/src/elements/snapshot/runtime/snapshot_capture.dart';
import 'package:fluvie/src/elements/snapshot/runtime/snapshot_capture_scope.dart';
import 'package:fluvie/src/media/media_bytes_loader.dart';
import 'package:fluvie/src/media/media_repository.dart';
import 'package:fluvie/src/media/net/media_http_client.dart';
import 'package:fluvie/src/media/runtime/image_resolver_scope.dart';

/// Pre-resolves every declared [SnapshotSource] before frame 0 with the offline
/// fake snapshot backend, or returns `null` when none are declared (decision
/// D-FakeDefault).
///
/// This is the snapshot parallel of `prepareEntryMedia`: the lesson 09 pre-pass
/// gathers a composition's `Mermaid`/`WebView`/`Html` sources and hands them
/// here, so each rasterizes once and paints synchronously from the first frame.
/// It uses [_OfflineFakeSnapshotService], which generates a deterministic raster
/// per request in-process, so the example renders offline with no Chromium and
/// no live network.
Future<MediaResolver?> prepareSnapshotMedia(Set<SnapshotSource> sources) async {
  if (sources.isEmpty) return null;
  final repository = MediaRepository(
    loader: MediaBytesLoader(
      bundle: rootBundle,
      httpClient: const _OfflineHttpClient(),
      allowlist: NetworkAllowlist.allowAny(),
      // Defense-in-depth: no untrusted snapshot reaches a FileSource today, but
      // honor the untrusted define so this loader stays hardened if ever wired in.
      // ignore: avoid_redundant_argument_values
      blockFileSources: const bool.fromEnvironment('FLUVIE_BLOCK_FILE_SOURCES'),
    ),
  );
  await preResolveSnapshotsOnto(repository, sources);
  return repository;
}

/// Pre-resolves [sources] onto an existing [repository] with the offline fake
/// backend, so the image and snapshot pre-passes can share one resolver.
///
/// `prepareEntryMedia` builds the real, ffmpeg-backed [MediaRepository] for a
/// composition's `Image`/`Clip` sources, then calls this to fold the same
/// composition's `Mermaid`/`WebView`/`Html` snapshots in — one resolver that
/// answers `decodedImageFor` and `decodedSnapshotFor` alike (decision
/// D-ResolverGrow). No-op when [sources] is empty.
Future<void> preResolveSnapshotsOnto(
  MediaRepository repository,
  Set<SnapshotSource> sources,
) async {
  if (sources.isEmpty) return;
  await repository.preResolveSnapshots(sources, const _OfflineFakeSnapshotService());
}

/// The in-process `Snapshot` subtree-capture pre-pass: rasterizes every
/// [Snapshot] in [scenes] exactly once before frame 0 and returns a
/// [SnapshotCaptureScope] holding the stills, or `null` when there are none
/// (P12-SNAP wiring, decision D-Snapshot).
///
/// This is the missing wire the capture shell needs. The render harness calls it
/// after `prepareEntryMedia` has decoded the composition's `Image`/`Clip` media,
/// then mounts the returned scope ABOVE the composition for the frame loop. Each
/// `Snapshot` child is rasterized under the same [resolver] (an
/// `ImageResolverScope`), so an inner `Image`/`Clip` paints from the decoded
/// cache during the `toImage` read-back — never an async pop-in or a live frame.
/// Unkeyed `Snapshot`s resolve in deterministic build order (the same order the
/// scope's cursor hands out), keyed `Snapshot`s by their widget [Key].
///
/// Drive this inside `tester.runAsync`: the `toImage` read-back completes on a
/// real engine callback that fake-async never pumps.
Future<SnapshotCaptureScope?> captureSnapshotScopeForScenes({
  required WidgetTester tester,
  required List<Scene> scenes,
  required MediaResolver? resolver,
  required int width,
  required int height,
}) async {
  final snapshots = collectSnapshots(scenes);
  if (snapshots.isEmpty) return null;
  final keyed = <Key, Widget>{};
  final unkeyed = <Widget>[];
  for (final snapshot in snapshots) {
    final key = snapshot.key;
    if (key != null) {
      keyed[key] = snapshot.child;
    } else {
      unkeyed.add(snapshot.child);
    }
  }
  final images = await captureSnapshotChildren(
    pump: _snapshotPump(tester, resolver, width, height),
    keyed: keyed,
    unkeyed: unkeyed,
  );
  return SnapshotCaptureScope(images: images);
}

/// A [SnapshotPump] that sizes the capture surface and mounts the child under the
/// media [resolver], so any inner `Image`/`Clip` paints from the decoded cache
/// while the subtree rasterizes.
SnapshotPump _snapshotPump(WidgetTester tester, MediaResolver? resolver, int width, int height) {
  return (boundaryKey, child) async {
    tester.view.physicalSize = ui.Size(width.toDouble(), height.toDouble());
    tester.view.devicePixelRatio = 1.0;
    Widget boundary = RepaintBoundary(
      key: boundaryKey,
      child: SizedBox(width: width.toDouble(), height: height.toDouble(), child: child),
    );
    if (resolver != null) {
      boundary = ImageResolverScope(resolver: resolver, child: boundary);
    }
    await tester.pumpWidget(Directionality(textDirection: TextDirection.ltr, child: boundary));
  };
}

/// The offline fake: rasterizes any request to a deterministic 16x12 PNG keyed
/// to the request's content, so the example never reaches a browser or network.
///
/// The fill color is derived from a content hash of the request (its canonical
/// `toString`), never `Object.hashCode` — `hashCode` varies between process runs
/// and would make the fixture raster non-deterministic, breaking the lesson 09
/// poster golden. The same request always yields the same pixels.
class _OfflineFakeSnapshotService implements SnapshotService {
  const _OfflineFakeSnapshotService();

  @override
  Future<SnapshotRaster> rasterize(SnapshotRequest request) async {
    const width = 16;
    const height = 12;
    final digest = fnv1a64Hex(utf8.encode(request.toString()));
    final seed = int.parse(digest.substring(0, 6), radix: 16) & 0xFFFFFF;
    final recorder = ui.PictureRecorder();
    ui.Canvas(recorder).drawRect(
      ui.Rect.fromLTWH(0, 0, width.toDouble(), height.toDouble()),
      ui.Paint()..color = ui.Color(0xFF000000 | seed),
    );
    final image = await recorder.endRecording().toImage(width, height);
    final data = await image.toByteData(format: ui.ImageByteFormat.png);
    image.dispose();
    final bytes = data!.buffer.asUint8List();
    return SnapshotRaster(
      bytes: bytes,
      contentHash: fnv1a64Hex(bytes),
      width: width,
      height: height,
    );
  }
}

/// The harness never reaches the live network: an unexpected fetch is a
/// determinism bug, not a download.
class _OfflineHttpClient implements MediaHttpClient {
  const _OfflineHttpClient();

  @override
  Future<Uint8List> get(Uri url) async => throw StateError(
    'The snapshot harness resolves only offline fixtures; an unexpected '
    'network source ($url) would break offline determinism.',
  );
}
