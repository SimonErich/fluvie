import 'package:flutter/animation.dart' show Curve;
import 'package:fluvie/src/core/ease.dart';
import 'package:fluvie/src/core/stagger.dart';
import 'package:fluvie/src/core/time.dart';
import 'package:meta/meta.dart';

/// Inheritable animation defaults: set once, overridable locally.
///
/// Precedence is **animation-local > `Scene` > `Video` > [package]**; each
/// field cascades independently, so a scene can pin the ease while the
/// duration still comes from the video or the package. A `null` field means
/// "unset — inherit from the level below", which is why every field is
/// nullable here even though the resolved cascade always ends in the non-null
/// [package] values.
@immutable
class Defaults {
  /// Creates a (possibly partial) set of defaults; `null` fields inherit.
  const Defaults({this.duration, this.ease, this.stagger});

  /// The bottom of the cascade — the package defaults:
  ///
  /// * [duration]: `Time.relative(0.2, max: Time.seconds(0.8))` — 20% of the
  ///   window, capped at 0.8 s, so animations scale with short scenes but
  ///   never crawl on long ones.
  /// * [ease]: [Ease.smooth].
  /// * [stagger]: none — staggering is always opt-in.
  static const Defaults package = Defaults(
    duration: Time.relative(0.2, max: Time.seconds(0.8)),
    ease: Ease.smooth,
  );

  /// How long a non-spring animation runs; `null` inherits.
  final Time? duration;

  /// The easing curve for non-spring animations; `null` inherits.
  final Curve? ease;

  /// The multi-child stagger applied when none is given; `null` inherits.
  final Stagger? stagger;

  /// Returns these defaults layered over [base]: every non-null field of
  /// `this` wins, every `null` field falls through to [base].
  ///
  /// Chain merges bottom-up to realise the cascade:
  ///
  /// ```dart
  /// local.mergeOver(scene.mergeOver(video.mergeOver(Defaults.package)))
  /// ```
  Defaults mergeOver(Defaults base) => Defaults(
    duration: duration ?? base.duration,
    ease: ease ?? base.ease,
    stagger: stagger ?? base.stagger,
  );

  @override
  bool operator ==(Object other) =>
      other is Defaults &&
      other.duration == duration &&
      other.ease == ease &&
      other.stagger == stagger;

  @override
  int get hashCode => Object.hash(Defaults, duration, ease, stagger);

  @override
  String toString() => 'Defaults(duration: $duration, ease: $ease, stagger: $stagger)';
}
