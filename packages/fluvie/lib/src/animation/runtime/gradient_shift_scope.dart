import 'package:flutter/foundation.dart' show listEquals;
import 'package:flutter/widgets.dart';

/// Publishes one gradient shift's shaped progress and target colors to the
/// element below it — the data channel behind `Animation.gradientShift`.
///
/// `Keyframe` carries a single color, not a color list, so a gradient shift
/// cannot travel through the composed keyframe. Instead the transform-class
/// `GradientShiftEffect` mounts this scope around the animated element each
/// frame, and `Background.gradient`/`Background.radial` read it via [maybeOf]
/// and lerp their base colors pairwise toward [colors] at [progress]. The
/// nearest scope wins, so one gradient shift drives one element.
///
/// [progress] is published exactly as shaped by the pipeline — `0` before the
/// animation's span, `1` after it (the hold), and possibly outside `[0, 1]`
/// mid-flight on overshooting springs; consumers clamp where they lerp.
final class GradientShiftScope extends InheritedWidget {
  /// Provides [progress] and [colors] to every descendant of [child].
  const GradientShiftScope({
    required this.progress,
    required this.colors,
    required super.child,
    super.key,
  });

  /// The shift's shaped progress at the current frame: `0` is the base
  /// gradient untouched, `1` is fully shifted to [colors].
  final double progress;

  /// The target colors, pairing index-by-index with the consumer's base
  /// colors (the lists must be the same length).
  final List<Color> colors;

  /// The nearest enclosing scope above [context], or `null` outside any
  /// gradient shift — backgrounds then paint their base colors unchanged.
  static GradientShiftScope? maybeOf(BuildContext context) =>
      context.dependOnInheritedWidgetOfExactType<GradientShiftScope>();

  @override
  bool updateShouldNotify(GradientShiftScope oldWidget) =>
      oldWidget.progress != progress || !listEquals(oldWidget.colors, colors);
}
