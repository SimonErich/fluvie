import 'package:flutter/widgets.dart';
import 'package:fluvie/src/animation/animation_effect.dart';
import 'package:fluvie/src/rendering/runtime/frame_provider.dart';
import 'package:fluvie/src/timing/time_scope_provider.dart';

/// The effect behind `Animation.parallax`: a depth-scaled drift driven by the
/// scene's own progress, not the animation's window.
///
/// A transform-class effect — it wraps the child in a [FractionalTranslation]
/// (no pixel post-process), so it composes with keyframe animations like any
/// other widget-level transform. The offset is a fraction of the child's own
/// size: `depth × sceneProgress`, where `sceneProgress` is the frame's position
/// within the nearest scene window read from the frame clock. A small [depth]
/// barely moves (a far background), a larger one drifts more (a near layer), so
/// stacking elements at different depths reads as parallax.
///
/// Reading the scene clock (not the per-effect `progress`) means parallax stays
/// in sync with the scene across triggers and staggers, and is fully
/// deterministic: the same frame always yields the same offset.
final class ParallaxEffect implements AnimationEffect {
  /// Creates a parallax drift of [depth] element-sizes across the scene;
  /// defaults to `0.2` (a gentle far-layer drift).
  const ParallaxEffect({this.depth = 0.2});

  /// How far the child drifts over the whole scene, as a fraction of its own
  /// size. `0` holds still; larger values read as nearer layers.
  final double depth;

  @override
  Widget build(Widget child, double progress) => _ParallaxView(depth: depth, child: child);

  @override
  String toString() => 'ParallaxEffect(depth: $depth)';
}

/// Reads the frame clock and scene scope to translate [child] by the parallax
/// offset for the current frame.
final class _ParallaxView extends StatelessWidget {
  const _ParallaxView({required this.depth, required this.child});

  final double depth;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final frame = FrameProvider.of(context).frame;
    final scope = TimeScopeProvider.of(context);
    final span = scope.durationFrames;
    final raw = span <= 0 ? 0.0 : (frame - scope.startFrame) / span;
    final sceneProgress = raw < 0
        ? 0.0
        : raw > 1
        ? 1.0
        : raw;
    return FractionalTranslation(
      translation: Offset(0, depth * sceneProgress),
      child: child,
    );
  }
}
