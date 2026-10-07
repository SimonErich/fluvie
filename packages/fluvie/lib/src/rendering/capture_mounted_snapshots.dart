import 'dart:ui' as ui;
import 'package:fluvie/src/core/errors/fluvie_render_exception.dart';
import 'package:fluvie/src/elements/snapshot/runtime/snapshot_capture.dart';
import 'package:fluvie/src/elements/snapshot/runtime/snapshot_capture_scope.dart';
import 'package:fluvie/src/rendering/composition_session.dart';

/// Freezes mounted boundaries, preserving custom component state and scopes.
Future<SnapshotCaptureScope?> captureMountedSnapshots({
  required CompositionSession session,
  required Future<void> Function() pump,
}) async {
  final targets = session.snapshotBoundaries;
  if (targets.isEmpty) return null;
  final images = <SnapshotCaptureKey, ui.Image>{};
  var unkeyedIndex = 0;
  try {
    for (final target in targets) {
      await session.prepareFrame(target.frame);
      session.selectedSnapshotBoundary = target.targetKey;
      await pump();
      final key = target.snapshot.key;
      final captureKey = key == null
          ? SnapshotCaptureKey.index(unkeyedIndex++)
          : SnapshotCaptureKey.keyed(key);
      if (images.containsKey(captureKey)) {
        throw FluvieRenderException('Snapshot keys must be unique in a composition: $key.');
      }
      images[captureKey] = await captureBoundaryImage(target.captureKey);
    }
    return SnapshotCaptureScope(images: images);
  } on Object {
    for (final image in images.values) {
      image.dispose();
    }
    rethrow;
  } finally {
    session.selectedSnapshotBoundary = null;
  }
}
