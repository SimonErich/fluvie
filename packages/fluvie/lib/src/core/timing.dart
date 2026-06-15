import 'package:flutter/animation.dart' show Curve;
import 'package:fluvie/src/core/ease.dart';
import 'package:fluvie/src/core/time.dart';
import 'package:meta/meta.dart';

/// How an animation progresses through time.
///
/// Animations are timed **either** by a fixed [Tween] (`duration + ease`)
/// **or** by a physics-driven [Spring], which derives its own duration from
/// its settle time. Setting a spring ignores any `duration`/`ease`; the
/// resolver computes the settle time for windowing and `Trigger.previous`
/// chaining.
@immutable
sealed class Timing {
  /// Const base constructor shared by both variants.
  const Timing();
}

/// Fixed-duration timing: progress follows [ease] over [duration].
///
/// This deliberately shadows Flutter's `Tween<T>` — the `fluvie` barrel hides
/// Flutter's so the short name reads naturally in video code. Where you need
/// Flutter's tween, import `package:flutter/animation.dart` with a prefix.
final class Tween extends Timing {
  /// Creates a tween that runs for [duration], shaped by [ease].
  const Tween(this.duration, {this.ease = Ease.smooth});

  /// How long the animation runs.
  final Time duration;

  /// The curve shaping progress over [duration]; defaults to [Ease.smooth].
  final Curve ease;

  @override
  bool operator ==(Object other) =>
      other is Tween && other.duration == duration && other.ease == ease;

  @override
  int get hashCode => Object.hash(Tween, duration, ease);

  @override
  String toString() => 'Tween($duration, ease: $ease)';
}

/// Physics-driven timing: a damped spring that derives its own duration.
///
/// The spring solves `mass·x″ + damping·x′ + stiffness·x = 0` from a unit
/// displacement; its *settle time* — computed by `SpringSolver` — becomes the
/// animation window, so chaining with `Trigger.previous` works after a spring
/// exactly as after a tween.
///
/// Feel is governed by the damping ratio `ζ = damping / (2·√(stiffness·mass))`
/// (`ζ < 1` overshoots and oscillates; `ζ = 1` is critically damped; `ζ > 1`
/// crawls without overshoot) and by the natural frequency `ω = √(stiffness /
/// mass)`, which sets the speed. The presets below pick `ζ` for character and
/// `ω` for pace.
final class Spring extends Timing {
  /// Creates a spring; defaults give a lively, moderately bouncy motion
  /// (`ζ ≈ 0.45`).
  const Spring({
    this.stiffness = 180,
    this.damping = 12,
    this.mass = 1,
    this.initialVelocity = 0,
  }) : assert(stiffness > 0, 'Spring.stiffness must be > 0'),
       assert(mass > 0, 'Spring.mass must be > 0'),
       assert(damping >= 0, 'Spring.damping must be >= 0');

  /// Soft and unhurried: `ζ ≈ 0.64`, `ω ≈ 11 rad/s` — one mild overshoot
  /// at a slow pace. Ambient moves and relaxed reveals.
  static const Spring gentle = Spring(stiffness: 120, damping: 14);

  /// Quick with restraint: `ζ ≈ 0.62` (the same overshoot as [gentle]) but
  /// `ω ≈ 16 rad/s`, so it gets there much faster. Crisp UI pops.
  static const Spring snappy = Spring(stiffness: 260, damping: 20);

  /// Clearly underdamped: `ζ ≈ 0.37` — the default stiffness of `180` with
  /// the damping lowered to `10`, giving several visible oscillations before
  /// settling. Playful, attention-grabbing entrances.
  static const Spring bouncy = Spring(damping: 10);

  /// Fast and flat: `ζ = 0.70`, `ω = 20 rad/s` — the quickest settle of the
  /// presets with barely perceptible overshoot. Decisive, no-nonsense motion.
  static const Spring stiff = Spring(stiffness: 400, damping: 28);

  /// The spring constant `k` (restoring force per unit displacement); higher
  /// is faster. Must be positive.
  final double stiffness;

  /// The viscous friction coefficient `c`; higher kills oscillation sooner.
  /// Must be non-negative (zero oscillates forever).
  final double damping;

  /// The moving mass `m`; higher is heavier and slower. Must be positive.
  final double mass;

  /// The starting velocity `x′(0)` in displacement units per second; non-zero
  /// values let a spring inherit momentum from a previous gesture or motion.
  final double initialVelocity;

  @override
  bool operator ==(Object other) =>
      other is Spring &&
      other.stiffness == stiffness &&
      other.damping == damping &&
      other.mass == mass &&
      other.initialVelocity == initialVelocity;

  @override
  int get hashCode => Object.hash(Spring, stiffness, damping, mass, initialVelocity);

  @override
  String toString() =>
      'Spring(stiffness: $stiffness, damping: $damping, '
      'mass: $mass, initialVelocity: $initialVelocity)';
}
