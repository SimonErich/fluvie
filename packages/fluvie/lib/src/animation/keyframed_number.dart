import 'package:flutter/animation.dart' show Curve;
import 'package:fluvie/src/core/ease.dart';
import 'package:fluvie/src/core/errors/fluvie_spec_error.dart';
import 'package:fluvie/src/core/time.dart';
import 'package:fluvie/src/core/time_order.dart';
import 'package:fluvie/src/serialization/codecs/curve_codec.dart';
import 'package:fluvie/src/serialization/codecs/time_codec.dart';
import 'package:fluvie/src/timing/time_scope_data.dart';
import 'package:meta/meta.dart';

/// Where a parameter is, and how long its element lives, at one frame.
///
/// The three things a keyframed value needs and nothing more: `progress`
/// places the frame inside the element's window, and `fps` with `windowFrames`
/// turn a stop's authored `Time` into a fraction of that window.
typedef EffectFrame = ({double progress, int fps, int windowFrames});

/// A number that changes over its element's life: ordered stops, one authored
/// position each, and one easing per segment between them.
///
/// The vocabulary is the `keyframes` animation form's, deliberately: the same
/// `positions` and `easings` keys, the same arity laws (one position per stop,
/// one easing per segment), and the same strictly-increasing rule. Only the
/// stop list differs, because these stops are plain numbers rather than
/// keyframe structs — so it is `values`, which is what they are.
///
/// **This is the parameter pattern.** Colour, audio automation and transition
/// parameters all read a number that may vary over time; they use this rather
/// than each inventing a shape of their own.
///
/// Resolution is a pure function of the frame, so capture stays synchronous
/// and two pumps of one frame read the same number.
@immutable
final class KeyframedNumber {
  /// Creates a keyframed value over [values] at [positions], eased by
  /// [easings].
  const KeyframedNumber({required this.values, required this.positions, required this.easings});

  /// The common case as a shorthand: every segment linear.
  KeyframedNumber.linear({required List<double> values, required List<Time> positions})
    : this(
        values: values,
        positions: positions,
        easings: List.filled(values.length - 1, Ease.linear),
      );

  /// Reads one from [json], or returns null when [json] is not the keyframed
  /// shape at all (a plain number is not an error, it is the other case).
  ///
  /// Throws a [FluvieSpecError] (located at [path]) for the shape's own rules:
  /// fewer than two stops, a position per stop, an easing per segment, and
  /// positions that increase.
  static KeyframedNumber? maybeFromJson(Object? json, {List<String> path = const []}) {
    if (json is! Map<String, Object?>) return null;
    final raw = json['values'];
    if (raw is! List) {
      throw FluvieSpecError('A keyframed value needs a "values" list', path: path);
    }
    for (final key in json.keys) {
      if (key != 'values' && key != 'positions' && key != 'easings') {
        throw FluvieSpecError(
          'Unknown property "$key" on a keyframed value. '
          'allowed: easings, positions, values.',
          path: path,
        );
      }
    }
    final values = <double>[
      for (var i = 0; i < raw.length; i++)
        if (raw[i] case final num value)
          value.toDouble()
        else
          throw FluvieSpecError('Expected a number', path: [...path, 'values', '$i']),
    ];
    if (values.length < 2) {
      throw FluvieSpecError(
        'A keyframed value needs at least two stops; one stop is a plain number',
        path: [...path, 'values'],
      );
    }
    final positions = _positions(json['positions'], values.length, [...path, 'positions']);
    final easings = _easings(json['easings'], values.length, [...path, 'easings']);
    return KeyframedNumber(values: values, positions: positions, easings: easings);
  }

  /// The value at each stop, in time order.
  final List<double> values;

  /// Where each stop sits, one per value, strictly increasing.
  final List<Time> positions;

  /// The curve of each segment, one fewer than there are values.
  final List<Curve> easings;

  /// The value at [frame].
  ///
  /// Held at the first stop before the first position and at the last after
  /// the last, so a parameter never jumps to a value nobody authored just
  /// because the playhead left the span between its stops.
  double at(EffectFrame frame) {
    final total = frame.windowFrames;
    if (total <= 0) return values.first;
    final scope = TimeScopeData(fps: frame.fps, startFrame: 0, durationFrames: total);
    final fractions = [for (final time in positions) time.resolveFrames(scope) / total];
    if (frame.progress <= fractions.first) return values.first;
    if (frame.progress >= fractions.last) return values.last;
    var segment = 0;
    while (frame.progress > fractions[segment + 1]) {
      segment += 1;
    }
    final from = fractions[segment];
    final to = fractions[segment + 1];
    final span = to - from;
    final local = span <= 0 ? 1.0 : (frame.progress - from) / span;
    final eased = easings[segment].transform(local.clamp(0.0, 1.0));
    return values[segment] + (values[segment + 1] - values[segment]) * eased;
  }

  /// The JSON form, writing `easings` only when it says something a default
  /// would not.
  Map<String, Object?> toJson() => {
    'values': values,
    'positions': [for (final position in positions) encodeTime(position)],
    if (easings.any((curve) => curve != Ease.linear))
      'easings': [for (final curve in easings) encodeCurve(curve)],
  };

  @override
  String toString() => 'KeyframedNumber(${values.length} stops)';
}

List<Time> _positions(Object? raw, int stops, List<String> path) {
  if (raw is! List || raw.length != stops) {
    throw FluvieSpecError(
      'A keyframed value needs one position per stop: expected $stops',
      path: path,
    );
  }
  final positions = [
    for (var i = 0; i < raw.length; i++) decodeTime(raw[i], path: [...path, '$i']),
  ];
  final clock = sameClockValues(positions);
  if (clock != null) {
    for (var i = 1; i < clock.length; i++) {
      if (clock[i] <= clock[i - 1]) {
        throw FluvieSpecError(
          'Positions must strictly increase; "${raw[i]}" does not come after '
          '"${raw[i - 1]}"',
          path: [...path, '$i'],
        );
      }
    }
  }
  return positions;
}

List<Curve> _easings(Object? raw, int stops, List<String> path) {
  if (raw == null) return List.filled(stops - 1, Ease.linear);
  if (raw is! List || raw.length != stops - 1) {
    throw FluvieSpecError(
      'A keyframed value needs one easing per segment: expected ${stops - 1}',
      path: path,
    );
  }
  return [
    for (var i = 0; i < raw.length; i++) decodeCurve(raw[i], path: [...path, '$i']),
  ];
}
