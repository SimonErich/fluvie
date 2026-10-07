import 'package:flutter/widgets.dart';
import 'package:fluvie/src/animation/runtime/effect_layer.dart';
import 'package:fluvie/src/composition/runtime/collectible_children.dart';
import 'package:fluvie/src/rendering/runtime/frame_provider.dart';
import 'package:fluvie/src/timing/time_scope_provider.dart';

/// Wraps [child] in [effects], driving each one from the frame.
///
/// A declared effect has no span of its own, so its progress is the element's
/// own: zero where the element comes alive and one where it goes. That is what
/// gives grain its shimmer and a glitch its jitter for nothing, and it is a
/// pure function of the frame, so capture stays synchronous and two pumps of
/// one frame paint the same pixels.
///
/// Ordering is the caller's: this mounts what it is handed, innermost first.
///
/// Each entry is a function of the frame rather than a fixed effect, because a
/// parameter may be keyframed. A still parameter simply ignores the frame it
/// is handed, so the two cases cost the same to mount.
final class EffectStack extends StatelessWidget implements CollectibleChildren {
  /// Wraps [child] in [effects], first applied innermost.
  const EffectStack({required this.effects, required this.child, super.key});

  /// The layers to apply, innermost first, each resolved at the frame.
  final List<EffectLayer> effects;

  /// The element being wrapped.
  final Widget child;

  /// Effects leave the declared child visible to media and timing prepasses.
  @override
  Iterable<Widget> get collectibleChildren => [child];

  @override
  Widget build(BuildContext context) {
    final frame = FrameProvider.of(context).frame;
    final scope = TimeScopeProvider.of(context);
    final span = scope.durationFrames;
    final raw = span <= 0 ? 0.0 : (frame - scope.startFrame) / span;
    final progress = raw < 0
        ? 0.0
        : raw > 1
        ? 1.0
        : raw;
    final at = (progress: progress, fps: scope.fps, windowFrames: span);
    var result = child;
    for (final layer in effects) {
      result = layer.resolve(at).build(result, progress);
    }
    return result;
  }
}
