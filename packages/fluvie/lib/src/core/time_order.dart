import 'package:fluvie/src/core/time.dart';

/// Every position mapped onto its family's shared clock — frames, absolute
/// milliseconds (seconds and milliseconds mix), or uncapped relative
/// fractions — or null when the positions mix families and only the resolver
/// (which knows the span and fps) can order them.
///
/// This is the one comparability rule every `positions` list follows: the
/// `keyframes` animation form and keyframed effect parameters both check
/// strict increase exactly when this answers, so the two forms can never
/// drift on what "in order" means.
List<double>? sameClockValues(List<Time> positions) {
  if (positions.every((position) => position is FrameTime)) {
    return [for (final position in positions) (position as FrameTime).frames.toDouble()];
  }
  if (positions.every((position) => position is MsTime || position is SecondTime)) {
    return [
      for (final position in positions)
        if (position is MsTime)
          position.milliseconds.toDouble()
        else
          (position as SecondTime).seconds * 1000,
    ];
  }
  if (positions.every((position) => position is RelativeTime && position.max == null)) {
    return [for (final position in positions) (position as RelativeTime).fraction];
  }
  return null;
}
