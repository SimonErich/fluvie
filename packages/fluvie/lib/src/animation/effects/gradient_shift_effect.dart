import 'package:flutter/widgets.dart';
import 'package:fluvie/src/animation/animation_effect.dart';
import 'package:fluvie/src/animation/runtime/gradient_shift_scope.dart';

/// The effect behind `Animation.gradientShift`: publishes the shift's
/// progress and target colors to the element below it.
///
/// A transform-class effect that paints nothing itself — [build] mounts a
/// [GradientShiftScope] around the child, and the gradient-capable element
/// inside (`Background.gradient`/`Background.radial`) lerps its base colors
/// pairwise toward [to] at the published progress. Because transform effects
/// wrap outside the keyframe applier, the scope always sits above the
/// background it drives, and the progress hold gives "base colors before
/// the span, shifted colors after it" for free.
final class GradientShiftEffect implements AnimationEffect {
  /// Creates a shift toward [to]; the list must pair index-by-index with the
  /// consuming background's base colors.
  const GradientShiftEffect(this.to);

  /// The target colors at progress `1`.
  final List<Color> to;

  @override
  Widget build(Widget child, double progress) =>
      GradientShiftScope(progress: progress, colors: to, child: child);

  @override
  String toString() => 'GradientShiftEffect(to: $to)';
}
