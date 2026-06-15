import 'dart:math' as math;

import 'package:flutter/widgets.dart';
import 'package:fluvie/src/rendering/runtime/frame_provider.dart';

/// Freezes a subtree at [holdFrame]: republishes the enclosing
/// [FrameProvider] clamped to `min(frame, holdFrame)`.
///
/// The transition compositor wraps a non-overlap outgoing scene in this
/// during the blend window, so every animation inside — they all read
/// `FrameProvider.of` — renders its final-frame values for as long as the
/// hold lasts. Once the parent frame passes [holdFrame] the republished
/// frame stops changing, [FrameProvider.updateShouldNotify] stays `false`,
/// and the held subtree never rebuilds: deterministic by construction.
///
/// Frames below the hold pass through unchanged, so mounting the clamp
/// early is harmless.
final class FrameClamp extends StatelessWidget {
  /// Clamps the frame visible to [child] at [holdFrame].
  const FrameClamp({required this.holdFrame, required this.child, super.key});

  /// The last frame the subtree advances to; later parent frames republish
  /// this one.
  final int holdFrame;

  /// The subtree being held.
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final frame = FrameProvider.of(context).frame;
    return FrameProvider(frame: math.min(frame, holdFrame), child: child);
  }
}
