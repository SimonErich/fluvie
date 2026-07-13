import 'package:fluvie/src/composition/introspection/frame_span.dart';
import 'package:fluvie/src/core/animation_phase.dart';
import 'package:meta/meta.dart';

/// One resolved animation on an introspected element: its phase, its
/// absolute frame [span], and its diagnostic [label].
///
/// Index-aligned with the element's declared animations, so the `i`-th
/// introspection describes the `i`-th `.animate()` entry.
@immutable
final class AnimationIntrospection {
  /// Creates the introspection of one animation.
  const AnimationIntrospection({required this.phase, required this.span, this.label});

  /// When the animation plays within its element's window
  /// (enter, exit, or during).
  final AnimationPhase phase;

  /// The absolute frames the animation occupies.
  final FrameSpan span;

  /// The animation's diagnostic label, or `null` when it has none.
  final String? label;

  @override
  String toString() {
    final name = label == null ? '' : '$label, ';
    return 'AnimationIntrospection($name${phase.name}, $span)';
  }
}
