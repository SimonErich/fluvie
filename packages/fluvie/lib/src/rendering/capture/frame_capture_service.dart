import 'package:flutter/widgets.dart';
import 'package:fluvie/src/rendering/capture/raw_frame.dart';
import 'package:fluvie/src/rendering/capture/repaint_boundary_capture_service.dart';
import 'package:riverpod/riverpod.dart';

/// Captures the pixels of one already-pumped frame as a [RawFrame].
///
/// The render loop owns the clock: it seeks the controller, pumps the tree,
/// and only then asks this service for the pixels. Implementations therefore
/// never advance time, never await anything frame-dependent, and capture the
/// same pixels for an identical pumped tree, which is what the frame cache and
/// the golden harness rely on.
// ignore: one_member_abstracts — the capture seam is mockable behind its provider (new-service).
abstract interface class FrameCaptureService {
  /// Reads the current pixels of the boundary under [boundaryKey] at exactly
  /// [width]x[height], tagged with [frameIndex].
  ///
  /// Throws a `FluvieRenderException` when the boundary is missing, is not a
  /// repaint boundary, or paints at a different size than requested.
  Future<RawFrame> capture({
    required GlobalKey boundaryKey,
    required int frameIndex,
    required int width,
    required int height,
  });
}

/// The capture service used by the render pipeline; defaults to
/// [RepaintBoundaryCaptureService] and is overridable in tests.
final frameCaptureServiceProvider = Provider<FrameCaptureService>(
  (ref) => const RepaintBoundaryCaptureService(),
);
