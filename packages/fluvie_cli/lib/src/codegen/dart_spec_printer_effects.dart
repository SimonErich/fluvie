part of 'dart_spec_printer.dart';

/// [base] wrapped in its effect stack, or [base] unchanged when the element
/// declares none.
///
/// The printed form is one `.effects([...])` call in the same slot the spec
/// builds it: inside the animate wrapper and outside the element itself. A
/// disabled effect prints with its flag, because it is still in the document.
String _effectsArg(Object? effects, String base) {
  if (effects is! List || effects.isEmpty) return base;
  final items = [
    for (final effect in effects)
      if (effect is Map<String, Object?>) _effect(effect),
  ];
  if (items.isEmpty) return base;
  return '$base.effects([${items.join(', ')}])';
}

/// One effect literal: the named factory when the document says only what the
/// factory can, the spec spelling when it cannot — a keyframed parameter, a
/// disabled effect, or a typed object parameter like particles.
String _effect(Map<String, Object?> effect) {
  final kind = effect['kind'];
  final params = <String, Object?>{
    for (final entry in effect.entries)
      if (entry.key != 'kind' && entry.key != 'enabled') entry.key: entry.value,
  };
  final simple =
      effect['enabled'] != false &&
      kind != 'particles' &&
      kind != 'curves' &&
      !params.entries.any((entry) => _isKeyframed(entry.key, entry.value));
  if (simple) {
    return 'Effect.$kind(${_args([
      for (final entry in params.entries) '${entry.key}: ${_effectValue(entry.value)}',
    ])})';
  }
  final spec = _args([
    'EffectSpecKind.$kind',
    if (effect['enabled'] == false) 'enabled: false',
    if (params.isNotEmpty)
      'params: {${params.entries.map((e) => "${_str(e.key)}: ${_effectParam(e.key, e.value)}").join(', ')}}',
  ]);
  return 'Effect.spec(EffectSpec($spec))';
}

/// Whether [value] under the parameter key [key] is a keyframed number.
///
/// The test is structural — the exact three-key shape, one position per
/// stop — and object-typed parameters are excluded by name, because a
/// shader author is free to name a uniform "values" and that names a float
/// slot, not a ramp. The exclusion list mirrors `EffectSpecKind`'s object
/// parameters; a new object parameter joins both in the same change.
bool _isKeyframed(String key, Object? value) {
  if (key == 'particles' || key == 'uniforms' || key == 'curves') return false;
  if (value is! Map<String, Object?>) return false;
  if (!value.keys.every((k) => k == 'values' || k == 'positions' || k == 'easings')) return false;
  final values = value['values'];
  final positions = value['positions'];
  return values is List &&
      values.length >= 2 &&
      values.every((v) => v is num) &&
      positions is List &&
      positions.length == values.length;
}

String _effectParam(String key, Object? value) =>
    value is Map<String, Object?> && _isKeyframed(key, value)
    ? _keyframed(value)
    : _effectValue(value);

String _effectValue(Object? value) => switch (value) {
  final String text => _str(text),
  final Map<String, Object?> object =>
    '{${object.entries.map((e) => "${_str(e.key)}: ${_effectValue(e.value)}").join(', ')}}',
  final num number => _num(number),
  final List<Object?> list => '[${list.map(_effectValue).join(', ')}]',
  _ => '$value',
};

/// A keyframed parameter as its Dart literal: the same three parts the
/// document carries, in the same order, so a reader who knows one form knows
/// the other.
String _keyframed(Map<String, Object?> value) {
  final easings = value['easings'];
  final values = 'values: ${_effectValue(value['values'])}';
  final positions =
      'positions: [${(value['positions']! as List<Object?>).map((t) => _time(t! as String)).join(', ')}]';
  if (easings is! List) return 'KeyframedNumber.linear(${_args([values, positions])})';
  return 'KeyframedNumber(${_args([
    values,
    positions,
    'easings: [${easings.map(_ease).join(', ')}]',
  ])})';
}
