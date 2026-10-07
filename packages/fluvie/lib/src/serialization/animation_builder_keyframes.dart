part of 'animation_builder.dart';

/// Builds the multi-stop `keyframes` form: at least two decoded stops, an
/// optional per-segment `easings` list (one curve per segment), optional
/// `positions` (one `Time` per stop), and an optional `phase` — plus the
/// common timing tail, whose `at` stays the start trigger (the Dart
/// constructor's `trigger` parameter).
///
/// Position ordering is validated here exactly as far as it is decidable at
/// parse time: positions that share one clock (all frames, all seconds/
/// milliseconds, or all uncapped relative fractions) must strictly increase.
/// Mixed-unit or capped-relative positions only meet once the animation span
/// and fps are known, so their ordering is left to the animation pipeline,
/// which checks the resolved stop fractions.
Animation _keyframesAnimation(AnimationSpec spec) {
  final args = spec.args;
  final raw = args['keyframes'];
  if (raw is! List) {
    throw FluvieSpecError('Expected a "keyframes" list of stops', path: const ['keyframes']);
  }
  if (raw.length < 2) {
    throw FluvieSpecError(
      'A keyframes animation needs at least two stops, got ${raw.length}',
      path: const ['keyframes'],
    );
  }
  final stops = <Keyframe>[
    for (var i = 0; i < raw.length; i++) decodeKeyframe(raw[i], path: ['keyframes', '$i']),
  ];
  return Animation.keyframes(
    stops,
    easings: _easings(args['easings'], stops.length),
    at: _positions(args['positions'], stops.length),
    phase: args['phase'] == null
        ? null
        : decodeEnum(AnimationPhase.values, args['phase'], 'phase', path: const ['phase']),
    duration: spec.duration,
    ease: spec.ease,
    spring: spec.spring,
    delay: spec.delay ?? Time.zero,
    trigger: spec.at ?? Trigger.auto,
    stagger: spec.stagger,
    repeat: spec.repeat,
    label: spec.label,
  );
}

/// The per-segment curves: exactly `stopCount - 1` named eases, or null.
List<Curve>? _easings(Object? raw, int stopCount) {
  if (raw == null) return null;
  if (raw is! List || raw.length != stopCount - 1) {
    throw FluvieSpecError(
      'Expected ${stopCount - 1} easings (one per segment between the '
      '$stopCount stops)',
      path: const ['easings'],
    );
  }
  return [
    for (var i = 0; i < raw.length; i++) decodeCurve(raw[i], path: ['easings', '$i']),
  ];
}

/// The declared stop positions: exactly one `Time` per stop, strictly
/// increasing whenever every position shares one comparable clock (see
/// [_keyframesAnimation]).
List<Time>? _positions(Object? raw, int stopCount) {
  if (raw == null) return null;
  if (raw is! List || raw.length != stopCount) {
    throw FluvieSpecError(
      'Expected $stopCount positions (one per stop)',
      path: const ['positions'],
    );
  }
  final positions = <Time>[
    for (var i = 0; i < raw.length; i++) decodeTime(raw[i], path: ['positions', '$i']),
  ];
  final values = sameClockValues(positions);
  if (values != null) {
    for (var i = 1; i < values.length; i++) {
      if (values[i] <= values[i - 1]) {
        throw FluvieSpecError(
          'Positions must strictly increase; "${raw[i]}" does not come after '
          '"${raw[i - 1]}"',
          path: ['positions', '$i'],
        );
      }
    }
  }
  return positions;
}
