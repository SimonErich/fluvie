import 'package:flutter/animation.dart' show Curve;
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

/// The JSON form of a [Curve]: its name in [namedEases].
///
/// Throws a [FluvieSpecError] (located at [path]) for any curve that is not a
/// named [Ease] member — the spec's easing vocabulary is the curated set.
String encodeCurve(Curve curve, {List<String> path = const []}) {
  for (final entry in namedEases.entries) {
    if (identical(entry.value, curve)) return entry.key;
  }
  throw FluvieSpecError('Unsupported easing curve $curve; use a named Ease', path: path);
}

/// Reads a [Curve] from an easing name in [raw].
///
/// Throws a [FluvieSpecError] (located at [path]) when [raw] is not a string or
/// names no member of [namedEases].
Curve decodeCurve(Object? raw, {List<String> path = const []}) {
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
