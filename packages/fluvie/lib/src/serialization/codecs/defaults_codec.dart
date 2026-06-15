import 'package:fluvie/src/core/defaults.dart';
import 'package:fluvie/src/core/errors/fluvie_spec_error.dart';
import 'package:fluvie/src/serialization/codecs/curve_codec.dart';
import 'package:fluvie/src/serialization/codecs/motion_codec.dart';
import 'package:fluvie/src/serialization/codecs/time_codec.dart';

/// The JSON form of [Defaults]: an object carrying only the set fields
/// (`duration`, `ease`, `stagger`); absent fields inherit the cascade.
Map<String, Object?> encodeDefaults(Defaults defaults) => {
  if (defaults.duration != null) 'duration': encodeTime(defaults.duration!),
  if (defaults.ease != null) 'ease': encodeCurve(defaults.ease!),
  if (defaults.stagger != null) 'stagger': encodeStagger(defaults.stagger!),
};

/// Reads [Defaults] from an object in [raw].
///
/// Throws a [FluvieSpecError] (located at [path]) when [raw] is not an object.
Defaults decodeDefaults(Object? raw, {List<String> path = const []}) {
  if (raw is! Map<String, Object?>) {
    throw FluvieSpecError('Expected a defaults object', path: path);
  }
  final duration = raw['duration'];
  final ease = raw['ease'];
  final stagger = raw['stagger'];
  return Defaults(
    duration: duration == null ? null : decodeTime(duration, path: [...path, 'duration']),
    ease: ease == null ? null : decodeCurve(ease, path: [...path, 'ease']),
    stagger: stagger == null ? null : decodeStagger(stagger, path: [...path, 'stagger']),
  );
}
