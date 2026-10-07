import 'package:flutter/painting.dart' show Color;
import 'package:fluvie/src/core/errors/fluvie_spec_error.dart';
import 'package:fluvie/src/core/particles/particles.dart';
import 'package:fluvie/src/serialization/codecs/color_codec.dart';
import 'package:fluvie/src/serialization/codecs/enum_codec.dart';

/// The keys a particles spec object may carry — the closed shape shared by
/// [decodeParticles] and the parser's unknown-property check.
const Set<String> knownParticlesKeys = {
  'kind',
  'count',
  'seed',
  'palette',
  'minSize',
  'maxSize',
  'fallSpeed',
  'drift',
  'spinSpeed',
};

/// Reads a [Particles] spec from an object in [raw].
///
/// The required `kind` (`confetti`, `snow`, or `sparkle`) picks the named
/// constructor; every other field is optional and falls back to that kind's
/// own default, so a spec that omits a field round-trips through the same
/// defaults the Dart constructors carry. Throws a [FluvieSpecError] (located
/// at [path]) for a missing/unknown kind or a mistyped field.
Particles decodeParticles(Object? raw, {List<String> path = const []}) {
  if (raw is! Map<String, Object?>) {
    throw FluvieSpecError('Expected a particles object with a "kind"', path: path);
  }
  final kind = decodeEnum(
    ParticleKind.values,
    raw['kind'],
    'particle kind',
    path: [...path, 'kind'],
  );
  final base = switch (kind) {
    ParticleKind.confetti => const Particles.confetti(),
    ParticleKind.snow => const Particles.snow(),
    ParticleKind.sparkle => const Particles.sparkle(),
  };
  final count = _int(raw, 'count', base.count, path);
  final seed = _string(raw, 'seed', base.seed, path);
  final palette = raw['palette'] == null ? base.palette : _palette(raw['palette'], path);
  final minSize = _double(raw, 'minSize', base.minSize, path);
  final maxSize = _double(raw, 'maxSize', base.maxSize, path);
  final fallSpeed = _double(raw, 'fallSpeed', base.fallSpeed, path);
  final drift = _double(raw, 'drift', base.drift, path);
  final spinSpeed = _double(raw, 'spinSpeed', base.spinSpeed, path);
  return switch (kind) {
    ParticleKind.confetti => Particles.confetti(
      count: count,
      seed: seed,
      palette: palette,
      minSize: minSize,
      maxSize: maxSize,
      fallSpeed: fallSpeed,
      drift: drift,
      spinSpeed: spinSpeed,
    ),
    ParticleKind.snow => Particles.snow(
      count: count,
      seed: seed,
      palette: palette,
      minSize: minSize,
      maxSize: maxSize,
      fallSpeed: fallSpeed,
      drift: drift,
      spinSpeed: spinSpeed,
    ),
    ParticleKind.sparkle => Particles.sparkle(
      count: count,
      seed: seed,
      palette: palette,
      minSize: minSize,
      maxSize: maxSize,
      fallSpeed: fallSpeed,
      drift: drift,
      spinSpeed: spinSpeed,
    ),
  };
}

int _int(Map<String, Object?> raw, String key, int fallback, List<String> path) {
  final value = raw[key];
  if (value == null) return fallback;
  if (value is int) return value;
  throw FluvieSpecError('Expected an integer "$key"', path: [...path, key]);
}

String _string(Map<String, Object?> raw, String key, String fallback, List<String> path) {
  final value = raw[key];
  if (value == null) return fallback;
  if (value is String) return value;
  throw FluvieSpecError('Expected a string "$key"', path: [...path, key]);
}

double _double(Map<String, Object?> raw, String key, double fallback, List<String> path) {
  final value = raw[key];
  if (value == null) return fallback;
  if (value is num) return value.toDouble();
  throw FluvieSpecError('Expected a number "$key"', path: [...path, key]);
}

List<Color> _palette(Object? raw, List<String> path) {
  if (raw is! List) {
    throw FluvieSpecError('Expected a list of colors "palette"', path: [...path, 'palette']);
  }
  return [
    for (final color in raw) decodeColor(color, path: [...path, 'palette']),
  ];
}
