/// @docImport 'package:fluvie/src/elements/snapshot/runtime/snapshot_capture.dart';
/// @docImport 'package:fluvie/src/elements/snapshot/snapshot.dart';
library;

import 'dart:ui' as ui;

import 'package:flutter/widgets.dart';

/// Identifies one [Snapshot] instance deterministically across the capture
/// pre-pass and the frame loop.
///
/// A `Snapshot` given an explicit [Key] resolves through [SnapshotCaptureKey.keyed]
/// — the most stable identity, independent of tree shape. An unkeyed `Snapshot`
/// resolves through [SnapshotCaptureKey.index]: the pre-pass and the frame loop
/// pump the same composition in the same order, so the n-th unkeyed `Snapshot`
/// gets the same index `n` in both passes (the [SnapshotCaptureScope] order
/// cursor hands them out in build order). The two variants never collide.
@immutable
sealed class SnapshotCaptureKey {
  const SnapshotCaptureKey._();

  /// A key derived from a `Snapshot`'s explicit widget [Key].
  const factory SnapshotCaptureKey.keyed(Key key) = _KeyedCaptureKey;

  /// A key derived from an unkeyed `Snapshot`'s stable build-order [index].
  const factory SnapshotCaptureKey.index(int index) = _IndexCaptureKey;
}

final class _KeyedCaptureKey extends SnapshotCaptureKey {
  const _KeyedCaptureKey(this.key) : super._();

  final Key key;

  @override
  bool operator ==(Object other) => other is _KeyedCaptureKey && other.key == key;

  @override
  int get hashCode => Object.hash(_KeyedCaptureKey, key);
}

final class _IndexCaptureKey extends SnapshotCaptureKey {
  const _IndexCaptureKey(this.index) : super._();

  final int index;

  @override
  bool operator ==(Object other) => other is _IndexCaptureKey && other.index == index;

  @override
  int get hashCode => Object.hash(_IndexCaptureKey, index);
}

/// Carries the pre-captured `Snapshot` subtree rasters down the tree in capture
/// — the analogue of `ImageResolverScope` for the in-process subtree-capture
/// path.
///
/// The render shell (the example harness) mounts one above the
/// composition before the frame loop, holding the [images] the pre-pass
/// rasterized once via [captureSnapshotChildren]. A `Snapshot` in capture reads
/// its raster from here and paints it synchronously every frame, never
/// re-rasterizing its child. In a live preview there is no scope and a
/// `Snapshot` passes its child through live.
///
/// The scope also owns a per-frame order cursor: unkeyed `Snapshot`s consume
/// [nextOrderIndex] in build order, so the n-th unkeyed `Snapshot` resolves the
/// same index `n` in the pre-pass and in the frame loop given a stable tree.
///
/// The cursor is a mutable field, so it MUST be returned to zero at the start of
/// every frame or its indices drift (frame 2's first `Snapshot` would read index
/// `2`, not `0`, and throw on a missing raster mid-render). The render shell
/// keeps the cursor stable in one of two equivalent ways:
///
/// - **A fresh scope per frame** (a new [SnapshotCaptureScope] carrying the same
///   [images]) starts every frame with a fresh cursor for free.
/// - **One persistent scope re-pumped per frame** (the harness frame-loop case,
///   where `tester.pump()` re-pumps the same tree) must call [resetCursor]
///   before each frame's pump.
///
/// Both are tested; neither drifts. Either way, no index drift may throw
/// mid-render.
final class SnapshotCaptureScope extends InheritedWidget {
  /// Provides the pre-captured [images] (keyed by [SnapshotCaptureKey]) to every
  /// descendant of [child].
  SnapshotCaptureScope({required this.images, super.child = const SizedBox.shrink(), super.key});

  /// The pre-captured subtree rasters, keyed by the capture key the `Snapshot`
  /// self-computes (its widget [Key], else its build-order index).
  final Map<SnapshotCaptureKey, ui.Image> images;

  // A mutable cursor on the (immutable) InheritedWidget instance. A fresh scope
  // per frame gets a fresh cursor for free; a persistent scope re-pumped per
  // frame must call resetCursor() before each pump (see the class dartdoc).
  final _OrderCursor _cursor = _OrderCursor();

  /// Hands out the next stable build-order index for an unkeyed `Snapshot`.
  int nextOrderIndex() => _cursor.next();

  /// Returns the order cursor to zero for the next frame's build pass.
  ///
  /// A persistent scope re-pumped per frame (the harness frame-loop case) calls
  /// this before each frame's pump so the n-th unkeyed `Snapshot` reads index
  /// `n` every frame; a fresh-scope-per-frame shell never needs it.
  void resetCursor() => _cursor.reset();

  /// The pre-captured image for [captureKey], or `null` when none was captured.
  ui.Image? imageFor(SnapshotCaptureKey captureKey) => images[captureKey];

  /// The nearest scope above [context], or `null` when there is none (a live
  /// preview, not a capture).
  static SnapshotCaptureScope? maybeOf(BuildContext context) =>
      context.dependOnInheritedWidgetOfExactType<SnapshotCaptureScope>();

  /// The nearest scope above [context]; throws a [FlutterError] when there is
  /// none, naming the missing scope.
  static SnapshotCaptureScope of(BuildContext context) {
    final scope = maybeOf(context);
    if (scope == null) {
      throw FlutterError(
        'No SnapshotCaptureScope found in context. A Snapshot in capture needs '
        'the pre-pass scope above it; the render shell mounts one before the '
        'frame loop.',
      );
    }
    return scope;
  }

  /// A copy of this scope wrapping a new [child], reusing the same [images]
  /// (a convenience for re-pumping the same captures around a fresh subtree).
  SnapshotCaptureScope copyWithChild(Widget child) =>
      SnapshotCaptureScope(images: images, child: child);

  @override
  bool updateShouldNotify(SnapshotCaptureScope oldWidget) => !identical(oldWidget.images, images);
}

final class _OrderCursor {
  int _next = 0;

  int next() => _next++;

  void reset() => _next = 0;
}
