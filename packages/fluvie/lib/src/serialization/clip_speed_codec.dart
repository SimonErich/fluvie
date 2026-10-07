import 'package:fluvie/src/animation/keyframed_number.dart';
import 'package:fluvie/src/core/errors/fluvie_spec_error.dart';

/// Parses the shared keyframed-number grammar for positive clip speed ramps.
/// Scalar rates keep the existing `speed` path and return null here.
KeyframedNumber? decodeClipSpeedRamp(Object? raw, {List<String> path = const ['speed']}) {
  final ramp = KeyframedNumber.maybeFromJson(raw, path: path);
  if (ramp == null) return null;
  if (ramp.values.any((value) => !value.isFinite || value <= 0)) {
    throw FluvieSpecError(
      'A speed ramp needs finite positive rates; use scalar Reverse for backwards playback',
      path: path,
    );
  }
  for (var segment = 0; segment < ramp.easings.length; segment++) {
    for (var sample = 0; sample <= 1024; sample++) {
      final eased = ramp.easings[segment].transform(sample / 1024);
      final rate = ramp.values[segment] + (ramp.values[segment + 1] - ramp.values[segment]) * eased;
      if (!rate.isFinite || rate <= 0) {
        throw FluvieSpecError('Speed ramp easing must never cross zero', path: path);
      }
    }
  }
  return ramp;
}
