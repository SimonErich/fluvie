/// @docImport 'package:fluvie/src/rendering/runtime/frame_provider.dart';
/// @docImport 'package:fluvie/src/rendering/runtime/render_controller_scope.dart';
library;

import 'package:flutter/foundation.dart';

/// Drives the frame index during capture and scrubbing — the only clock.
///
/// The render loop (or the inspector's scrubber) calls [seek] / [advance];
/// a [RenderControllerScope] above the composition republishes [frame] as a
/// [FrameProvider] so descendants rebuild deterministically per frame. There
/// is no ticker and no wall-clock anywhere: a frame changes only when someone
/// explicitly moves it, which is what makes capture reproducible.
final class RenderController extends ValueNotifier<int> {
  /// Creates a controller positioned at [initialFrame] (>= 0).
  RenderController({int initialFrame = 0})
    : assert(initialFrame >= 0, 'initialFrame must be >= 0, got $initialFrame'),
      super(initialFrame);

  /// The current frame index.
  int get frame => value;

  /// Jumps to [frame] (>= 0). Listeners are notified only when the frame
  /// actually changes; seeking to the current frame is a no-op.
  void seek(int frame) {
    assert(frame >= 0, 'frame must be >= 0, got $frame');
    value = frame;
  }

  /// Steps forward [by] frames (default 1) via [seek].
  void advance([int by = 1]) => seek(value + by);
}
