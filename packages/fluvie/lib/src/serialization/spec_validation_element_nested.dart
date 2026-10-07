part of 'spec_validation.dart';

/// A rich `Text`'s spans: each span is a closed shape, and the style inside
/// each span is the same closed text-style subset as a top-level `style`.
void _checkSpans(Map<String, Object?> json, List<String> path, List<FluvieSpecWarning> out) {
  _checkEachNested(json, 'spans', _textSpanFields, 'a text span', path, out);
  final spans = json['spans'];
  if (spans is! List) return;
  for (var i = 0; i < spans.length; i++) {
    final entry = spans[i];
    if (entry is! Map<String, Object?>) continue;
    _checkNested(entry, 'style', _styleOrTokenFields, 'a text style', [
      ...path,
      'spans',
      '$i',
    ], out);
  }
}

/// A `Chart`'s closed nested shapes: the stagger, each series (and the points
/// inside it), and each top-level point.
void _checkChart(Map<String, Object?> json, List<String> path, List<FluvieSpecWarning> out) {
  _checkNested(json, 'stagger', _staggerFields, 'a stagger', path, out);
  _checkEachNested(json, 'series', _chartSeriesFields, 'a chart series', path, out);
  _checkEachNested(json, 'points', _chartPointFields, 'a chart point', path, out);
  final series = json['series'];
  if (series is! List) return;
  for (var i = 0; i < series.length; i++) {
    final entry = series[i];
    if (entry is! Map<String, Object?>) continue;
    _checkEachNested(entry, 'points', _chartPointFields, 'a chart point', [
      ...path,
      'series',
      '$i',
    ], out);
  }
}

/// A `Box` decoration and the closed shapes one level inside it.
void _checkDecoration(Map<String, Object?> json, List<String> path, List<FluvieSpecWarning> out) {
  _checkNested(json, 'decoration', knownDecorationKeys, 'a decoration', path, out);
  final decoration = json['decoration'];
  if (decoration is! Map<String, Object?>) return;
  final decorationPath = [...path, 'decoration'];
  _checkNested(decoration, 'border', knownDecorationBorderKeys, 'a border', decorationPath, out);
  _checkNested(
    decoration,
    'gradient',
    knownDecorationGradientKeys,
    'a gradient',
    decorationPath,
    out,
  );
  _checkNested(decoration, 'shadow', knownDecorationShadowKeys, 'a shadow', decorationPath, out);
}

/// Like `_checkNested`, but for a list-valued [key]: every map entry in the
/// list is a closed shape over [allowed].
void _checkEachNested(
  Map<String, Object?> json,
  String key,
  Set<String> allowed,
  String subject,
  List<String> path,
  List<FluvieSpecWarning> out,
) {
  final list = json[key];
  if (list is! List) return; // Wrong type: the codec reports it.
  for (var i = 0; i < list.length; i++) {
    final entry = list[i];
    if (entry is! Map<String, Object?>) continue;
    final entryPath = [...path, key, '$i'];
    for (final prop in entry.keys) {
      if (allowed.contains(prop)) continue;
      out.add(FluvieSpecWarning(_message(prop, subject, allowed, null), path: entryPath));
    }
  }
}

/// Reports every unknown key on an effect entry.
///
/// The kind's own key set is the authority, so a typo inside an effect is
/// named here rather than being dropped into a stack that renders something
/// its author did not write.
void _checkEffects(Object? raw, List<String> path, List<FluvieSpecWarning> out) {
  if (raw is! List) return;
  for (var i = 0; i < raw.length; i++) {
    final effect = raw[i];
    if (effect is! Map<String, Object?>) continue;
    final EffectSpecKind kind;
    try {
      kind = EffectSpecKind.fromJson(effect['kind']);
    } on FluvieSpecError {
      continue; // An unknown kind is the parser's to report, not a warning.
    }
    final allowed = {'kind', 'enabled', ...kind.knownKeys};
    for (final key in effect.keys) {
      if (allowed.contains(key)) continue;
      out.add(
        FluvieSpecWarning(
          _message(key, 'a ${kind.name} effect', kind.knownKeys, kind.name),
          path: [...path, 'effects', '$i'],
        ),
      );
    }
  }
}
