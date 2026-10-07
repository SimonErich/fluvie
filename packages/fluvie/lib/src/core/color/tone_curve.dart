import 'package:meta/meta.dart';

/// A monotone tone curve through control points on the unit square: what the
/// master curve, the per-channel curves and the editor's curve editor all
/// evaluate. One evaluator, so a curve reads the same everywhere it is drawn.
///
/// Interpolation is Fritsch–Carlson monotone cubic: the curve passes through
/// every control point exactly, never overshoots between two increasing
/// points, and holds flat across a plateau. Outside the first and last point
/// the value holds, and every read clamps to `[0, 1]`. Evaluation is a pure
/// function of the points, so a baked lookup is stable run to run.
@immutable
final class ToneCurve {
  const ToneCurve._(this._xs, this._ys, this._slopes);

  const ToneCurve._identity() : _xs = const [0, 1], _ys = const [0, 1], _slopes = const [1, 1];

  /// The curve through [points] (`(x, y)` pairs, x strictly increasing).
  ///
  /// Throws an [ArgumentError] for fewer than two points or positions that
  /// do not strictly increase.
  factory ToneCurve.fromPoints(List<(double, double)> points) {
    if (points.length < 2) {
      throw ArgumentError.value(points, 'points', 'A curve needs at least two points');
    }
    for (final (x, y) in points) {
      // Before the clamp: NaN clamps to a limit rather than staying NaN,
      // which is exactly the silent corruption this refusal exists for.
      if (!x.isFinite || !y.isFinite) {
        throw ArgumentError.value(points, 'points', 'Points must be finite numbers');
      }
    }
    final xs = <double>[for (final (x, _) in points) x];
    final ys = <double>[for (final (_, y) in points) y.clamp(0.0, 1.0)];
    for (var i = 1; i < xs.length; i++) {
      if (xs[i] <= xs[i - 1]) {
        throw ArgumentError.value(points, 'points', 'Positions must strictly increase');
      }
    }
    return ToneCurve._(xs, ys, _monotoneSlopes(xs, ys));
  }

  /// The diagonal: every read answers its input exactly.
  static const ToneCurve identity = ToneCurve._identity();

  final List<double> _xs;
  final List<double> _ys;
  final List<double> _slopes;

  /// Whether this curve is the diagonal, so a caller can skip the work.
  bool get isIdentity {
    if (_xs.length != 2) return false;
    return _xs[0] == 0 && _xs[1] == 1 && _ys[0] == 0 && _ys[1] == 1;
  }

  /// The curve's value at [x], clamped to `[0, 1]` and held outside the
  /// first and last point.
  double at(double x) {
    // The identity is exact by definition, not by arithmetic: the Hermite
    // basis reconstructs the diagonal only to floating error, and "renders
    // what it always rendered" is a byte-level claim.
    if (isIdentity) return x.clamp(0.0, 1.0);
    if (x <= _xs.first) return _ys.first;
    if (x >= _xs.last) return _ys.last;
    var segment = 0;
    while (x > _xs[segment + 1]) {
      segment += 1;
    }
    final h = _xs[segment + 1] - _xs[segment];
    final t = (x - _xs[segment]) / h;
    final t2 = t * t;
    final t3 = t2 * t;
    final value =
        (2 * t3 - 3 * t2 + 1) * _ys[segment] +
        (t3 - 2 * t2 + t) * h * _slopes[segment] +
        (-2 * t3 + 3 * t2) * _ys[segment + 1] +
        (t3 - t2) * h * _slopes[segment + 1];
    return value.clamp(0.0, 1.0);
  }

  /// [count] evenly spaced reads across `[0, 1]`, ends included — the baked
  /// lookup a shader samples.
  List<double> sample(int count) => [
    for (var i = 0; i < count; i++) at(count == 1 ? 0 : i / (count - 1)),
  ];

  /// The Fritsch–Carlson tangents: secant-averaged, zeroed across a plateau,
  /// and limited so no segment can overshoot its endpoints.
  static List<double> _monotoneSlopes(List<double> xs, List<double> ys) {
    final n = xs.length;
    final secants = [for (var i = 0; i < n - 1; i++) (ys[i + 1] - ys[i]) / (xs[i + 1] - xs[i])];
    final slopes = List<double>.filled(n, 0);
    slopes[0] = secants.first;
    slopes[n - 1] = secants.last;
    for (var i = 1; i < n - 1; i++) {
      slopes[i] = secants[i - 1] * secants[i] <= 0 ? 0 : (secants[i - 1] + secants[i]) / 2;
    }
    for (var i = 0; i < n - 1; i++) {
      if (secants[i] == 0) {
        slopes[i] = 0;
        slopes[i + 1] = 0;
        continue;
      }
      final a = slopes[i] / secants[i];
      final b = slopes[i + 1] / secants[i];
      final limit = a * a + b * b;
      if (!limit.isFinite) {
        // A near-zero secant beside a steep one overflows the ratio; the
        // honest limit is the flattest one, exactly as a zero secant reads.
        slopes[i] = 0;
        slopes[i + 1] = 0;
        continue;
      }
      if (limit > 9) {
        final scale = 3 / _sqrt(limit);
        slopes[i] = scale * a * secants[i];
        slopes[i + 1] = scale * b * secants[i];
      }
    }
    return slopes;
  }

  /// Newton's square root, so `core` stays free of `dart:math`.
  static double _sqrt(double value) {
    if (value <= 0) return 0;
    var guess = value;
    for (var i = 0; i < 32; i++) {
      guess = (guess + value / guess) / 2;
    }
    return guess;
  }

  @override
  String toString() => 'ToneCurve(${_xs.length} points)';
}
