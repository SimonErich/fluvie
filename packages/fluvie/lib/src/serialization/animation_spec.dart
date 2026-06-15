import 'package:flutter/animation.dart' show Curve;
import 'package:fluvie/src/core/errors/fluvie_spec_error.dart';
import 'package:fluvie/src/core/repeat.dart';
import 'package:fluvie/src/core/stagger.dart';
import 'package:fluvie/src/core/time.dart';
import 'package:fluvie/src/core/timing.dart';
import 'package:fluvie/src/core/trigger.dart';
import 'package:fluvie/src/serialization/anchor_table.dart';
import 'package:fluvie/src/serialization/codecs/curve_codec.dart';
import 'package:fluvie/src/serialization/codecs/motion_codec.dart';
import 'package:fluvie/src/serialization/codecs/time_codec.dart';
import 'package:fluvie/src/serialization/codecs/trigger_codec.dart';

/// The preset names the spec can build, mapped to nothing — a set kept as a map
/// key list so an unknown preset fails at parse time.
const Set<String> knownAnimationPresets = {
  'fadeIn',
  'fadeOut',
  'slideIn',
  'slideOut',
  'slideFade',
  'pop',
  'scaleIn',
  'blurIn',
  'blurOut',
  'grain',
  'vignette',
  'spin',
  'drift',
  'kenBurns',
};

/// The data form of one `.animate([...])` entry: either a named preset plus its
/// arguments, or a raw `from`/`to`/`fromTo` keyframe animation, in both cases
/// carrying the common timing tail (`duration`, `ease`, `spring`, `delay`,
/// `at`, `stagger`, `repeat`, `label`).
///
/// This is a pure data object: `buildAnimation` turns it into a real
/// `Animation`. The reserved keys that make up the tail are never treated as
/// preset arguments.
class AnimationSpec {
  /// Creates an animation spec of [kind] with preset/raw [args] and the common
  /// timing tail.
  AnimationSpec({
    required this.kind,
    this.args = const {},
    this.duration,
    this.ease,
    this.spring,
    this.delay,
    this.at,
    this.stagger,
    this.repeat,
    this.label,
  });

  /// Reads an animation spec from [json], resolving anchor ids through
  /// [anchors].
  ///
  /// A `"preset"` key selects a named preset (validated against
  /// [knownAnimationPresets]); otherwise a `from`/`to` keyframe selects the raw
  /// `from`/`to`/`fromTo` form. Throws a [FluvieSpecError] (located at [path])
  /// for an unknown preset or a node that is neither.
  factory AnimationSpec.fromJson(
    Map<String, Object?> json,
    AnchorTable anchors, {
    List<String> path = const [],
  }) {
    const tailKeys = {
      'duration',
      'ease',
      'spring',
      'delay',
      'at',
      'stagger',
      'repeat',
      'label',
    };
    final preset = json['preset'];
    final String kind;
    final args = <String, Object?>{};
    if (preset is String) {
      if (!knownAnimationPresets.contains(preset)) {
        throw FluvieSpecError('Unknown animation preset "$preset"', path: path);
      }
      kind = preset;
      for (final entry in json.entries) {
        if (entry.key != 'preset' && !tailKeys.contains(entry.key)) {
          args[entry.key] = entry.value;
        }
      }
    } else if (json.containsKey('from') && json.containsKey('to')) {
      kind = 'fromTo';
      args['from'] = json['from'];
      args['to'] = json['to'];
    } else if (json.containsKey('from')) {
      kind = 'from';
      args['from'] = json['from'];
    } else if (json.containsKey('to')) {
      kind = 'to';
      args['to'] = json['to'];
    } else {
      throw FluvieSpecError(
        'An animation needs a "preset" or a "from"/"to" keyframe',
        path: path,
      );
    }
    return AnimationSpec(
      kind: kind,
      args: args,
      duration: _time(json['duration'], [...path, 'duration']),
      ease: json['ease'] == null ? null : decodeCurve(json['ease'], path: [...path, 'ease']),
      spring: json['spring'] == null
          ? null
          : decodeSpring(json['spring'], path: [...path, 'spring']),
      delay: _time(json['delay'], [...path, 'delay']),
      at: json['at'] == null ? null : decodeTrigger(json['at'], anchors, path: [...path, 'at']),
      stagger: json['stagger'] == null
          ? null
          : decodeStagger(json['stagger'], path: [...path, 'stagger']),
      repeat: json['repeat'] == null
          ? null
          : decodeRepeat(json['repeat'], path: [...path, 'repeat']),
      label: json['label'] is String ? json['label']! as String : null,
    );
  }

  /// The preset name (`fadeIn`, ...) or the raw kind (`from`/`to`/`fromTo`).
  final String kind;

  /// The preset-specific (or raw-keyframe) arguments, stored verbatim.
  final Map<String, Object?> args;

  /// The animation duration, or null to inherit the `Defaults` cascade.
  final Time? duration;

  /// The easing curve, or null to inherit.
  final Curve? ease;

  /// The spring timing, or null for tween/inherited timing.
  final Spring? spring;

  /// The delay after the trigger fires, or null for none.
  final Time? delay;

  /// The start trigger, or null for `Trigger.auto`.
  final Trigger? at;

  /// The multi-child stagger, or null to inherit.
  final Stagger? stagger;

  /// The repeat policy, or null for a single pass.
  final Repeat? repeat;

  /// The diagnostic label, or null for none.
  final String? label;

  /// Whether this is a raw `from`/`to`/`fromTo` animation (no preset name).
  bool get isRaw => kind == 'from' || kind == 'to' || kind == 'fromTo';

  /// The JSON form: a `preset` (unless raw) plus [args] and the set tail fields.
  Map<String, Object?> toJson() => {
    if (!isRaw) 'preset': kind,
    ...args,
    if (duration != null) 'duration': encodeTime(duration!),
    if (ease != null) 'ease': encodeCurve(ease!),
    if (spring != null) 'spring': encodeSpring(spring!),
    if (delay != null) 'delay': encodeTime(delay!),
    if (at != null) 'at': encodeTrigger(at!),
    if (stagger != null) 'stagger': encodeStagger(stagger!),
    if (repeat != null) 'repeat': encodeRepeat(repeat!),
    if (label != null) 'label': label,
  };

  static Time? _time(Object? raw, List<String> path) =>
      raw == null ? null : decodeTime(raw, path: path);
}
