import 'package:flutter/widgets.dart';
import 'package:fluvie/src/core/noise/noise_source.dart';
import 'package:fluvie/src/core/noise/value_noise.dart';

/// Carries the resolved [NoiseSource] down to `ctx.noise` and the seeded
/// effects that read it — the randomness counterpart
/// to the audio `ReactiveScope`.
///
/// The render shell mounts one of these over the composition with the source
/// from `noiseSourceProvider`. Unlike the throwing clocks, [of] is
/// non-throwing: with no scope it returns a `const ValueNoise()`, the same
/// algorithm the effects default to, so a tree with no scope reads byte-identical
/// noise and a live preview needs no wrapper at all.
final class NoiseScope extends InheritedWidget {
  /// Provides [source] to every descendant of [child].
  const NoiseScope({required this.source, required super.child, super.key});

  /// The seeded source every descendant reads through [of] / `ctx.noise`.
  final NoiseSource source;

  /// The nearest source above [context], or a `const ValueNoise()` when there
  /// is none — the same default the effects carry, so noise stays consistent
  /// whether or not a shell mounted a scope.
  static NoiseSource of(BuildContext context) => maybeOf(context) ?? const ValueNoise();

  /// The nearest source above [context], or `null` when no scope is present.
  static NoiseSource? maybeOf(BuildContext context) =>
      context.dependOnInheritedWidgetOfExactType<NoiseScope>()?.source;

  @override
  bool updateShouldNotify(NoiseScope oldWidget) => oldWidget.source != source;
}
