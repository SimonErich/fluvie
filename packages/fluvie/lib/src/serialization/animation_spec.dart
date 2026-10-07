import 'package:flutter/animation.dart' show Curve;
import 'package:fluvie/src/core/errors/fluvie_spec_error.dart';
import 'package:fluvie/src/core/repeat.dart';
import 'package:fluvie/src/core/stagger.dart';
import 'package:fluvie/src/core/time.dart';
import 'package:fluvie/src/core/timing.dart';
import 'package:fluvie/src/core/trigger.dart';
import 'package:fluvie/src/serialization/anchor_table.dart';
import 'package:fluvie/src/serialization/animation_catalog.dart';
import 'package:fluvie/src/serialization/codecs/curve_codec.dart';
import 'package:fluvie/src/serialization/codecs/motion_codec.dart';
import 'package:fluvie/src/serialization/codecs/time_codec.dart';
import 'package:fluvie/src/serialization/codecs/trigger_codec.dart';

export 'package:fluvie/src/serialization/animation_catalog.dart';

/// The data form of one `.animate([...])` entry: a named preset plus its
/// arguments, a multi-stop `keyframes` animation, or a raw `from`/`to`/
/// `fromTo` keyframe animation — in every case carrying the common timing
/// tail (`duration`, `ease`, `spring`, `delay`, `at`, `stagger`, `repeat`,
/// `label`).
///
/// This is a pure data object: `buildAnimation` turns it into a real
/// `Animation`. The reserved keys that make up the tail are never treated as
/// preset arguments. In the `keyframes` form the stop positions live under
/// `positions`, so the tail's `at` keeps meaning the start trigger — exactly
/// like the Dart constructor, which renames its trigger parameter for the
/// same reason.
final class AnimationSpec {
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
  /// [knownAnimationPresets]); a `"keyframes"` list selects the multi-stop
  /// keyframes form (with its optional `easings`, `positions`, and `phase`);
  /// otherwise a `from`/`to` keyframe selects the raw `from`/`to`/`fromTo`
  /// form. Throws a [FluvieSpecError] (located at [path]) for an unknown
  /// preset or a node that is none of the three.
  factory AnimationSpec.fromJson(
    Map<String, Object?> json,
    AnchorTable anchors, {
    List<String> path = const [],
  }) {
    final preset = json['preset'];
    final String kind;
    final args = <String, Object?>{};
    if (preset is String) {
      if (!knownAnimationPresets.contains(preset)) {
        throw FluvieSpecError('Unknown animation preset "$preset"', path: path);
      }
      kind = preset;
      for (final entry in json.entries) {
        if (!reservedAnimationKeys.contains(entry.key)) {
          args[entry.key] = entry.value;
        }
      }
    } else if (json.containsKey('keyframes')) {
      kind = 'keyframes';
      args['keyframes'] = json['keyframes'];
      if (json.containsKey('easings')) args['easings'] = json['easings'];
      if (json.containsKey('positions')) args['positions'] = json['positions'];
      if (json.containsKey('phase')) args['phase'] = json['phase'];
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
        'An animation needs a "preset", a "keyframes" list, or a "from"/"to" keyframe',
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

  /// The keys every animation entry reads regardless of its preset: the
  /// selector plus the common timing tail. Everything else is a preset
  /// argument owned by the preset.
  static const Set<String> reservedAnimationKeys = {
    'preset',
    'duration',
    'ease',
    'spring',
    'delay',
    'at',
    'stagger',
    'repeat',
    'label',
  };

  /// The preset name (`fadeIn`, ...), the multi-stop `keyframes` kind, or the
  /// raw kind (`from`/`to`/`fromTo`).
  final String kind;

  /// The preset-specific (or keyframe-form) arguments, stored verbatim.
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

  /// Whether this is the multi-stop `keyframes` form; like the raw forms it is
  /// self-naming, so [toJson] writes no `preset` key for it.
  bool get isKeyframes => kind == 'keyframes';

  /// The JSON form: a `preset` (unless the form is self-naming) plus [args]
  /// and the set tail fields.
  Map<String, Object?> toJson() => {
    if (!isRaw && !isKeyframes) 'preset': kind,
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
