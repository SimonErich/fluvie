import 'package:fluvie/src/core/snapshot/snapshot_raster.dart';
import 'package:fluvie/src/core/snapshot/snapshot_request.dart';

/// Rasterizes a [SnapshotRequest] to a decoded-ready [SnapshotRaster] — the one
/// boundary every snapshot-backed widget rides.
///
/// This is the boundary the determinism story leans on: rasterizing is async
/// (it may drive a headless browser), so it runs entirely in the pre-resolve
/// pass before frame 0; the resolver then decodes the raster once and serves it
/// synchronously during the frame loop. A snapshot is therefore "just another
/// resolved media" by the time paint reads it.
///
/// The gate default is a `FakeSnapshotService` serving committed fixture rasters
/// so tests never need a browser or the live network. The real
/// `ChromeSnapshotService` is best-effort and lives behind the `snapshot` test
/// tag; when no Chrome binary is present it throws a
/// `FluvieSnapshotUnavailableError` naming the install fix, never a blank frame.
///
/// `FakeSnapshotService` and `ChromeSnapshotService` are named in prose, not as
/// doc links, because they live in layers above `core`.
// ignore: one_member_abstracts — the contract is the type: injectable where a bare function isn't.
abstract interface class SnapshotService {
  /// Rasterizes [request] to a [SnapshotRaster], asynchronously.
  ///
  /// Runs in the pre-resolve pass before the frame loop. Throws a
  /// `FluvieSnapshotUnavailableError` when the backing capability is missing,
  /// and a `FluvieRenderException` when a present backend fails on the input.
  Future<SnapshotRaster> rasterize(SnapshotRequest request);
}
