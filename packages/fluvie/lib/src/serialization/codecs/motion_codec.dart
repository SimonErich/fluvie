import 'package:fluvie/src/core/errors/fluvie_spec_error.dart';
import 'package:fluvie/src/core/repeat.dart';
import 'package:fluvie/src/core/stagger.dart';
import 'package:fluvie/src/core/stagger_origin.dart';
import 'package:fluvie/src/core/time.dart';
import 'package:fluvie/src/core/timing.dart';
import 'package:fluvie/src/serialization/codecs/enum_codec.dart';
import 'package:fluvie/src/serialization/codecs/time_codec.dart';

/// The named [Spring] presets, by name.
const Map<String, Spring> namedSprings = {
  'gentle': Spring.gentle,
  'snappy': Spring.snappy,
  'bouncy': Spring.bouncy,
  'stiff': Spring.stiff,
};

/// The JSON form of a [Spring]: a preset name when it matches one, otherwise an
/// object carrying all four physical parameters.
Object encodeSpring(Spring spring) {
  for (final entry in namedSprings.entries) {
    if (entry.value == spring) return entry.key;
  }
  return {
    'stiffness': spring.stiffness,
    'damping': spring.damping,
    'mass': spring.mass,
    'initialVelocity': spring.initialVelocity,
  };
}

/// Reads a [Spring] from a preset name or an object in [raw].
///
/// Throws a [FluvieSpecError] (located at [path]) for an unknown name or a
/// non-spring value.
Spring decodeSpring(Object? raw, {List<String> path = const []}) {
  if (raw is String) {
    final spring = namedSprings[raw];
    if (spring == null) {
      throw FluvieSpecError(
        'Unknown spring "$raw"; expected gentle, snappy, bouncy, or stiff',
        path: path,
      );
    }
    return spring;
  }
  if (raw is Map<String, Object?>) {
    return Spring(
      stiffness: _double(raw['stiffness']) ?? 180,
      damping: _double(raw['damping']) ?? 12,
      mass: _double(raw['mass']) ?? 1,
      initialVelocity: _double(raw['initialVelocity']) ?? 0,
    );
  }
  throw FluvieSpecError('Expected a spring name or object', path: path);
}

/// The JSON form of a [Stagger]: an object tagged by its variant key
/// (`each`, `evenly`, or `from`).
Object encodeStagger(Stagger stagger, {List<String> path = const []}) => switch (stagger) {
  EachStagger(:final gap) => {'each': encodeTime(gap, path: path)},
  EvenlyStagger(:final over) => {'evenly': encodeTime(over, path: path)},
  OriginStagger(:final origin, :final gap) => {
    'from': encodeEnum(origin),
    if (gap != null) 'gap': encodeTime(gap, path: path),
  },
};

/// Reads a [Stagger] from an object in [raw].
///
/// Throws a [FluvieSpecError] (located at [path]) when no variant key is present.
Stagger decodeStagger(Object? raw, {List<String> path = const []}) {
  if (raw is Map<String, Object?>) {
    if (raw.containsKey('each')) return Stagger.each(decodeTime(raw['each'], path: path));
    if (raw.containsKey('evenly')) {
      return Stagger.evenly(over: decodeTime(raw['evenly'], path: path));
    }
    if (raw.containsKey('from')) {
      final origin = decodeEnum(StaggerOrigin.values, raw['from'], 'stagger origin', path: path);
      final gap = raw['gap'];
      return Stagger.from(origin, gap: gap == null ? null : decodeTime(gap, path: path));
    }
  }
  throw FluvieSpecError('Expected a stagger object with each, evenly, or from', path: path);
}

/// The JSON form of a [Repeat]: `{forever: true}` or `{times: n}`, with optional
/// `yoyo` and (for `times`) `gap`.
Map<String, Object?> encodeRepeat(Repeat repeat, {List<String> path = const []}) {
  if (repeat.isForever) {
    return {'forever': true, if (repeat.yoyo) 'yoyo': true};
  }
  return {
    'times': repeat.count,
    if (repeat.yoyo) 'yoyo': true,
    if (repeat.gap != Time.zero) 'gap': encodeTime(repeat.gap, path: path),
  };
}

/// Reads a [Repeat] from an object in [raw].
///
/// Throws a [FluvieSpecError] (located at [path]) when neither `forever` nor a
/// valid `times` is present.
Repeat decodeRepeat(Object? raw, {List<String> path = const []}) {
  if (raw is Map<String, Object?>) {
    final yoyo = raw['yoyo'] == true;
    if (raw['forever'] == true) return Repeat.forever(yoyo: yoyo);
    final times = raw['times'];
    if (times is int) {
      final gap = raw['gap'];
      return Repeat.times(
        times,
        yoyo: yoyo,
        gap: gap == null ? Time.zero : decodeTime(gap, path: path),
      );
    }
  }
  throw FluvieSpecError('Expected a repeat object with forever or times', path: path);
}

double? _double(Object? value) => value is num ? value.toDouble() : null;
