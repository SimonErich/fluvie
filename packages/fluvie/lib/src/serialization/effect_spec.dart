import 'package:fluvie/src/animation/keyframed_number.dart';
import 'package:fluvie/src/core/errors/fluvie_spec_error.dart';
import 'package:fluvie/src/serialization/effect_object_validation.dart';
import 'package:meta/meta.dart';

part 'effect_param.dart';
part 'effect_spec_kind.dart';

/// One entry of an element's effect stack: which effect, whether it runs, and
/// the parameters it was given.
///
/// Parameters are stored verbatim so a document round-trips exactly what its
/// author wrote; the defaults live on the kind and are read at build time.
@immutable
final class EffectSpec {
  /// Declares [kind] with [params].
  const EffectSpec(this.kind, {this.enabled = true, this.params = const {}});

  /// Reads one effect from [json].
  factory EffectSpec.fromJson(Map<String, Object?> json, {List<String> path = const []}) {
    final kind = EffectSpecKind.fromJson(json['kind'], path: [...path, 'kind']);
    final params = <String, Object?>{};
    for (final entry in json.entries) {
      if (entry.key == 'kind' || entry.key == 'enabled') continue;
      _checkParam(kind, entry.key, entry.value, [...path, entry.key]);
      params[entry.key] = entry.value;
    }
    validateEffectObjects(kind.name, params, path);
    return EffectSpec(kind, enabled: json['enabled'] != false, params: params);
  }

  /// Which effect this is.
  final EffectSpecKind kind;

  /// Whether it runs. A disabled effect stays in the document and mounts
  /// nothing, exactly as `visible: false` does for an element.
  final bool enabled;

  /// Its parameters, verbatim.
  final Map<String, Object?> params;

  /// The numeric [name] at [frame], or the kind's own default when the
  /// document is silent.
  ///
  /// A parameter is either a plain number or a keyframed one; both answer here,
  /// so nothing downstream has to know which it was.
  double number(String name, {EffectFrame frame = _still}) {
    final param = kind.params.firstWhere((p) => p.name == name);
    final raw = params[name];
    if (raw is num) return raw.toDouble();
    final keyframed = raw is KeyframedNumber ? raw : KeyframedNumber.maybeFromJson(raw);
    if (keyframed != null) return keyframed.at(frame).clamp(param.min, param.max);
    return param.defaultValue;
  }

  /// Whether [name] was authored as a keyframed value rather than a number.
  ///
  /// What an editor asks to decide between a plain field and a row of
  /// diamonds; the render path never needs it, because [number] answers either
  /// way.
  bool isKeyframed(String name) =>
      kind.params.any((param) => param.name == name) &&
      (params[name] is KeyframedNumber || params[name] is Map<String, Object?>);

  /// The keyframed [name], or null when it is a plain number.
  KeyframedNumber? keyframed(String name) => switch (isKeyframed(name) ? params[name] : null) {
    final KeyframedNumber live => live,
    final raw => KeyframedNumber.maybeFromJson(raw),
  };

  /// Whether any parameter of this effect varies over time, and so has to be
  /// rebuilt per frame.
  bool get varies => kind.params.any((p) => isKeyframed(p.name));

  /// The boolean [name], defaulting to false.
  bool flag(String name) => params[name] == true;

  /// The string [name], or null.
  String? text(String name) => params[name] is String ? params[name]! as String : null;

  /// The nested object [name], or null.
  Map<String, Object?>? object(String name) =>
      params[name] is Map<String, Object?> ? params[name]! as Map<String, Object?> : null;

  /// The JSON form: the kind, `enabled` only when it is off, then every
  /// parameter as written.
  Map<String, Object?> toJson() => {
    'kind': kind.name,
    if (!enabled) 'enabled': false,
    for (final entry in params.entries)
      entry.key: entry.value is KeyframedNumber
          ? (entry.value! as KeyframedNumber).toJson()
          : entry.value,
  };

  @override
  String toString() => 'EffectSpec(${kind.name}${enabled ? '' : ', off'})';
}

/// The frame a still parameter reads at: the element's start, where a plain
/// number is the same number it is everywhere else.
const EffectFrame _still = (progress: 0, fps: 30, windowFrames: 0);

/// Refuses a parameter the kind does not have, one of the wrong type, or a
/// number outside the effect's own range.
void _checkParam(EffectSpecKind kind, String key, Object? value, List<String> path) {
  if (!kind.knownKeys.contains(key)) {
    throw FluvieSpecError(
      'Unknown property "$key" on a ${kind.name} effect. '
      'Allowed: ${(kind.knownKeys.toList()..sort()).join(', ')}',
      path: path,
    );
  }
  if (kind.flags.contains(key)) {
    if (value is! bool) throw FluvieSpecError('Expected a boolean for "$key"', path: path);
    return;
  }
  if (kind.strings.contains(key)) {
    if (value is! String || value.isEmpty) {
      throw FluvieSpecError('Expected a non-empty string for "$key"', path: path);
    }
    return;
  }
  if (kind.objects.contains(key)) {
    if (value is! Map<String, Object?>) {
      throw FluvieSpecError('Expected an object for "$key"', path: path);
    }
    return;
  }
  final choices = kind.enums[key];
  if (choices != null) {
    if (value is! String || !choices.contains(value)) {
      throw FluvieSpecError(
        'Expected one of ${choices.join(', ')} for "$key"',
        path: path,
      );
    }
    return;
  }
  final param = kind.params.firstWhere((p) => p.name == key);
  if (value is Map<String, Object?>) {
    // A keyframed value: the shape checks itself, then every stop faces the
    // same range a literal would, because a ramp to 5 is as wrong as a 5.
    final keyframed = KeyframedNumber.maybeFromJson(value, path: path);
    if (keyframed == null) {
      throw FluvieSpecError('Expected a number or a keyframed value for "$key"', path: path);
    }
    for (var i = 0; i < keyframed.values.length; i++) {
      _checkRange(param, kind, key, keyframed.values[i], [...path, 'values', '$i']);
    }
    return;
  }
  if (value is! num) {
    throw FluvieSpecError('Expected a number or a keyframed value for "$key"', path: path);
  }
  _checkRange(param, kind, key, value.toDouble(), path);
}

/// Refuses a number outside the parameter's own range.
void _checkRange(
  EffectParam param,
  EffectSpecKind kind,
  String key,
  double value,
  List<String> path,
) {
  if (value >= param.min && value <= param.max) return;
  throw FluvieSpecError(
    '"$key" is ${param.min} to ${param.max} on a ${kind.name} effect; got $value',
    path: path,
  );
}
