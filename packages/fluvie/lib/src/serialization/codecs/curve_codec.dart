import 'package:flutter/animation.dart' show Cubic, Curve;
import 'package:fluvie/src/core/ease.dart';
import 'package:fluvie/src/core/errors/fluvie_spec_error.dart';

/// The named easing curves the spec understands, in canonical encode order.
///
/// Each maps to an [Ease] member. Several names share one curve (for example
/// `smooth` and `inOut` are both `Curves.easeInOut`); encoding returns the
/// first key in this map whose curve matches, so the canonical name wins.
const Map<String, Curve> namedEases = {
  'linear': Ease.linear,
  'smooth': Ease.smooth,
  'snappy': Ease.snappy,
  'gentle': Ease.gentle,
  'in': Ease.in_,
  'out': Ease.out,
  'inOut': Ease.inOut,
  'back': Ease.back,
  'bounce': Ease.bounce,
  'elastic': Ease.elastic,
};

/// The JSON form of a [Curve]: its name in [namedEases], or a cubic control-point object.
///
/// Throws a [FluvieSpecError] (located at [path]) for any curve that is not a
/// named [Ease] member or a [Cubic].
Object encodeCurve(Curve curve, {List<String> path = const []}) {
  for (final entry in namedEases.entries) {
    final named = entry.value;
    if (identical(named, curve) ||
        (named is Cubic &&
            curve is Cubic &&
            named.a == curve.a &&
            named.b == curve.b &&
            named.c == curve.c &&
            named.d == curve.d)) {
      return entry.key;
    }
  }
  if (curve is Cubic && curve.a == curve.b && curve.c == curve.d) return 'linear';
  if (curve is Cubic) {
    return {
      'cubic': [curve.a, curve.b, curve.c, curve.d],
    };
  }
  throw FluvieSpecError('Unsupported easing curve $curve; use a named Ease or Cubic', path: path);
}

/// Reads a named or cubic easing curve from [raw].
///
/// Throws a [FluvieSpecError] at [path] for unknown names, malformed cubic
/// controls, nonfinite values or x controls outside the unit interval.
Curve decodeCurve(Object? raw, {List<String> path = const []}) {
  if (raw is Map<String, Object?>) {
    final points = raw['cubic'];
    if (raw.length != 1 ||
        points is! List ||
        points.length != 4 ||
        points.any((v) => v is! num || !v.isFinite)) {
      throw FluvieSpecError('A cubic ease needs four finite control values', path: path);
    }
    final values = points.cast<num>().map((v) => v.toDouble()).toList();
    if (values[0] < 0 || values[0] > 1 || values[2] < 0 || values[2] > 1) {
      throw FluvieSpecError('Cubic ease x controls must be in [0, 1]', path: path);
    }
    return Cubic(values[0], values[1], values[2], values[3]);
  }
  if (raw is! String) {
    throw FluvieSpecError('Expected an easing name (a string)', path: path);
  }
  final curve = namedEases[raw];
  if (curve == null) {
    throw FluvieSpecError(
      'Unknown easing "$raw"; expected one of: ${namedEases.keys.join(', ')}',
      path: path,
    );
  }
  return curve;
}
