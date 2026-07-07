import 'dart:math' as math;

import 'package:fluvie/src/core/timing.dart';

/// Closed-form solver for the free damped spring `m·x″ + c·x′ + k·x = 0` with
/// `x(0) = 1` and `x′(0) = initialVelocity`: displacement decays from `1`
/// toward `0`.
///
/// All three damping regimes (under-, critically-, and over-damped) are
/// solved analytically — no numeric integration — so results are
/// deterministic across runs and platforms. Springs have no fixed duration:
/// [settleTime] is what Fluvie uses to window a spring-timed animation and to
/// chain `Trigger.previous` after it.
final class SpringSolver {
  /// Creates a solver for [spring], precomputing the regime coefficients.
  SpringSolver(this.spring) : _omega = math.sqrt(spring.stiffness / spring.mass) {
    final m = spring.mass;
    final c = spring.damping;
    final v0 = spring.initialVelocity;
    final cmk = c * c - 4 * m * spring.stiffness;
    if (cmk < 0) {
      _regime = _Regime.underdamped;
      _r1 = -c / (2 * m);
      _r2 = math.sqrt(-cmk) / (2 * m); // damped frequency ω_d
      _c1 = 1;
      _c2 = (v0 - _r1) / _r2;
      _d1 = _r1 * _c1 + _r2 * _c2;
      _d2 = _r1 * _c2 - _r2 * _c1;
      _decayRate = -_r1;
      _amplitude = math.max(_magnitude(_c1, _c2), _magnitude(_d1, _d2) / _omega);
    } else if (cmk == 0) {
      _regime = _Regime.critical;
      _r1 = -c / (2 * m);
      _r2 = _r1;
      _c1 = 1;
      _c2 = v0 - _r1;
      _d1 = _c2 + _r1 * _c1;
      _d2 = _r1 * _c2;
      _decayRate = -_r1 / 2;
      _amplitude = math.max(
        _peakLinearDecay(_c1.abs(), _c2.abs(), _decayRate),
        _peakLinearDecay(_d1.abs(), _d2.abs(), _decayRate) / _omega,
      );
    } else {
      _regime = _Regime.overdamped;
      final root = math.sqrt(cmk);
      _r1 = (-c - root) / (2 * m); // fast-decaying root
      _r2 = (-c + root) / (2 * m); // slow-decaying root
      _c2 = (v0 - _r1) / (_r2 - _r1);
      _c1 = 1 - _c2;
      _d1 = _c1 * _r1;
      _d2 = _c2 * _r2;
      _decayRate = -_r2;
      _amplitude = math.max(_c1.abs() + _c2.abs(), (_d1.abs() + _d2.abs()) / _omega);
    }
  }

  /// The spring being solved.
  final Spring spring;

  /// Natural frequency `ω = √(stiffness / mass)`, used to scale velocity into
  /// displacement units for the settle envelope.
  final double _omega;

  late final _Regime _regime;
  late final double _r1; // exponent rate (underdamped: σ; critical: r; overdamped: fast root)
  late final double _r2; // underdamped: ω_d; critical: r; overdamped: slow root
  late final double _c1; // displacement coefficients
  late final double _c2;
  late final double _d1; // velocity coefficients
  late final double _d2;
  late final double _decayRate; // envelope exponent α
  late final double _amplitude; // envelope amplitude M: bound(t) ≤ M·e^(−αt)

  /// The displacement at [t] seconds: starts at `1`, decays toward `0`.
  double value(double t) => switch (_regime) {
    _Regime.underdamped => math.exp(_r1 * t) * (_c1 * math.cos(_r2 * t) + _c2 * math.sin(_r2 * t)),
    _Regime.critical => (_c1 + _c2 * t) * math.exp(_r1 * t),
    _Regime.overdamped => _c1 * math.exp(_r1 * t) + _c2 * math.exp(_r2 * t),
  };

  /// The velocity `x′(t)` at [t] seconds; `velocity(0)` is the spring's
  /// `initialVelocity`.
  double velocity(double t) => switch (_regime) {
    _Regime.underdamped => math.exp(_r1 * t) * (_d1 * math.cos(_r2 * t) + _d2 * math.sin(_r2 * t)),
    _Regime.critical => (_d1 + _d2 * t) * math.exp(_r1 * t),
    _Regime.overdamped => _d1 * math.exp(_r1 * t) + _d2 * math.exp(_r2 * t),
  };

  /// The first time `T` (in seconds, at millisecond resolution) after which
  /// both `|value(t)|` and the velocity scaled into displacement units,
  /// `|velocity(t)| / ω`, stay within [epsilon] for every `t ≥ T`.
  ///
  /// Each regime admits an analytic exponential envelope `M·e^(−αt)` bounding
  /// both quantities: underdamped uses the oscillation envelope (`α = ζω`),
  /// overdamped the slow root, and critically damped a half-rate bound that
  /// absorbs the linear term. The solver starts from the closed-form estimate
  /// `ln(M/ε)/α` and refines on the 1 ms grid to the first tick where the
  /// envelope bound holds — fully deterministic.
  ///
  /// This settle time is the duration of a spring-timed animation's window
  /// and the moment `Trigger.previous` chains from.
  double settleTime({double epsilon = 0.001}) {
    assert(epsilon > 0, 'epsilon must be > 0');
    if (_amplitude <= epsilon) return 0;
    if (_decayRate <= 0) {
      throw ArgumentError.value(
        spring,
        'spring',
        'a zero-damping spring oscillates forever and cannot be windowed; '
            'give it damping > 0 or use a Tween',
      );
    }
    final estimate = math.log(_amplitude / epsilon) / _decayRate;
    var tick = (estimate * 1000).floor();
    if (tick < 0) tick = 0;
    while (_amplitude * math.exp(-_decayRate * (tick / 1000)) > epsilon) {
      tick += 1;
    }
    return tick / 1000;
  }

  /// [settleTime] expressed in whole frames at [fps]:
  /// `(settleTime * fps).ceil()`.
  int settleFrames(int fps, {double epsilon = 0.001}) {
    assert(fps > 0, 'fps must be > 0');
    return (settleTime(epsilon: epsilon) * fps).ceil();
  }

  static double _magnitude(double a, double b) => math.sqrt(a * a + b * b);

  /// The maximum of `(a + b·t)·e^(−α·t)` over `t ≥ 0` (for `a, b ≥ 0`):
  /// bounds the critically damped linear-times-exponential terms.
  static double _peakLinearDecay(double a, double b, double alpha) {
    if (b == 0) return a;
    final t = math.max(0, 1 / alpha - a / b).toDouble();
    return (a + b * t) * math.exp(-alpha * t);
  }
}

/// The three analytic solution families of the damped spring equation.
enum _Regime { underdamped, critical, overdamped }
