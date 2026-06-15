/// @docImport 'package:fluvie/src/elements/snapshot/snapshot.dart';
library;

import 'dart:ui' as ui;

import 'package:flutter/rendering.dart';
import 'package:flutter/widgets.dart';
import 'package:fluvie/src/elements/snapshot/runtime/snapshot_capture_scope.dart';

/// Pumps [child] under [boundaryKey] and lets the engine settle, so the
/// boundary is ready for a `toImage` read-back. The render shell (or a widget
/// test via `tester.pumpWidget`) supplies this; keeping it a callback keeps this
/// library free of the `flutter_test` dependency.
typedef SnapshotPump = Future<void> Function(GlobalKey boundaryKey, Widget child);

/// Rasterizes a set of `Snapshot` subtrees exactly once and returns the
/// capture-key -> `ui.Image` map for a [SnapshotCaptureScope].
///
/// Each child is wrapped in an offstage [RepaintBoundary] (by the caller's
/// [pump]) and captured once via [captureBoundaryImage] (`toImage` read-back).
/// The captured pixels are a pure function of the child — no wall-clock, no
/// async-in-frame — so the same child rasterizes to byte-identical pixels every
/// run. [keyed] children resolve to [SnapshotCaptureKey.keyed]; [unkeyed]
/// children resolve to [SnapshotCaptureKey.index] in list order.
///
/// Drive [pump] inside `tester.runAsync` (or the render shell's async pre-pass):
/// the `toImage` read-back completes on a real engine callback that fake-async
/// never drives. A full pre-pass that walks a real composition is the harness's
/// job (the render shell); this is the reusable primitive it composes.
Future<Map<SnapshotCaptureKey, ui.Image>> captureSnapshotChildren({
  required SnapshotPump pump,
  required Map<Key, Widget> keyed,
  required List<Widget> unkeyed,
}) async {
  final result = <SnapshotCaptureKey, ui.Image>{};
  for (final entry in keyed.entries) {
    result[SnapshotCaptureKey.keyed(entry.key)] = await _captureOne(pump, entry.value);
  }
  for (var i = 0; i < unkeyed.length; i++) {
    result[SnapshotCaptureKey.index(i)] = await _captureOne(pump, unkeyed[i]);
  }
  return result;
}

Future<ui.Image> _captureOne(SnapshotPump pump, Widget child) async {
  final boundaryKey = GlobalKey();
  await pump(boundaryKey, child);
  return captureBoundaryImage(boundaryKey);
}

/// Captures the pixels under [boundaryKey] as a `ui.Image` via the boundary's
/// `toImage(pixelRatio: 1.0)`.
///
/// The key must sit on an already-pumped [RepaintBoundary]; this mirrors the
/// frame pipeline's `RepaintBoundaryCaptureService` primitive but yields the
/// decoded image directly (a `Snapshot` paints the image, not raw RGBA bytes).
Future<ui.Image> captureBoundaryImage(GlobalKey boundaryKey) {
  final context = boundaryKey.currentContext;
  if (context == null) {
    throw FlutterError(
      'The Snapshot capture boundary is not mounted: pump the child under a '
      'RepaintBoundary(key: ...) before capturing.',
    );
  }
  final renderObject = context.findRenderObject();
  if (renderObject is! RenderRepaintBoundary) {
    throw FlutterError(
      'The Snapshot capture key must sit on a RepaintBoundary, but its render '
      'object is ${renderObject.runtimeType}.',
    );
  }
  return renderObject.toImage();
}
