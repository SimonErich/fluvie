import 'dart:convert';
import 'dart:ui' as ui;

import 'package:fluvie/rendering.dart';
// The snapshot value types are render infrastructure under `src/`, off the
// authoring surface a lesson imports; the `SnapshotService` contract itself is
// public via the barrel.
import 'package:fluvie/src/core/hash/fnv1a.dart';
import 'package:fluvie/src/core/snapshot/snapshot_raster.dart';
import 'package:fluvie/src/core/snapshot/snapshot_request.dart';

/// The offline fake: rasterizes any request to a deterministic 16x12 PNG keyed
/// to the request's content, so the example never reaches a browser or network.
///
/// The fill color is derived from a content hash of the request (its canonical
/// `toString`), never `Object.hashCode` — `hashCode` varies between process runs
/// and would make the fixture raster non-deterministic, breaking the lesson 09
/// poster golden. The same request always yields the same pixels.
class OfflineFakeSnapshotService implements SnapshotService {
  /// Creates the offline fake backend.
  const OfflineFakeSnapshotService();

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
