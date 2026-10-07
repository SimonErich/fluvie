part of 'effect_builder.dart';

/// The curves effect for [spec]: each named channel decoded through the one
/// evaluator, an absent channel staying the identity.
CurvesEffect _curves(EffectSpec spec, EffectFrame frame) {
  final channels = spec.object('curves') ?? const {};
  const allowed = {'master', 'red', 'green', 'blue'};
  for (final key in channels.keys) {
    if (!allowed.contains(key)) {
      throw FluvieSpecError(
        'Unknown curves channel "$key". Allowed: blue, green, master, red.',
        path: const ['effects', 'curves'],
      );
    }
  }
  ToneCurve channel(String name) {
    final raw = channels[name];
    if (raw == null) return ToneCurve.identity;
    if (raw is! List) {
      throw FluvieSpecError(
        'A curves channel is a list of [x, y] points',
        path: ['effects', 'curves', name],
      );
    }
    final points = <(double, double)>[];
    for (final entry in raw) {
      if (entry is! List || entry.length != 2 || entry.any((value) => value is! num)) {
        throw FluvieSpecError(
          'A curve point is a two-number [x, y] pair',
          path: ['effects', 'curves', name],
        );
      }
      points.add(((entry[0]! as num).toDouble(), (entry[1]! as num).toDouble()));
    }
    if (points.length < 2) {
      throw FluvieSpecError(
        'A curve needs at least two points',
        path: ['effects', 'curves', name],
      );
    }
    for (var i = 1; i < points.length; i++) {
      if (points[i].$1 <= points[i - 1].$1) {
        throw FluvieSpecError(
          'Curve positions must strictly increase',
          path: ['effects', 'curves', name],
        );
      }
    }
    return ToneCurve.fromPoints(points);
  }

  return CurvesEffect(
    master: channel('master'),
    red: channel('red'),
    green: channel('green'),
    blue: channel('blue'),
    intensity: spec.number('intensity', frame: frame),
  );
}
