part of 'theme_spec.dart';

// The ThemeSpec parser: every token name is an identifier and every value is
// literal (a palette entry is a hex string, a type-scale entry a literal
// style object), so a theme can never reference itself.

final RegExp _tokenName = RegExp(r'^[a-zA-Z][a-zA-Z0-9]*$');

ThemeSpec _parseTheme(Map<String, Object?> json, List<String> path) => ThemeSpec(
  palette: _parsePalette(json['palette'], [...path, 'palette']),
  typeScale: _parseTypeScale(json['typeScale'], [...path, 'typeScale']),
  spacing: _parseSpacing(json['spacing'], [...path, 'spacing']),
  motion: json['motion'] == null ? null : decodeDefaults(json['motion'], path: [...path, 'motion']),
);

Map<String, Color> _parsePalette(Object? raw, List<String> path) {
  final entries = _tokenMap(raw, path);
  final palette = <String, Color>{};
  for (final entry in entries.entries) {
    final value = entry.value;
    if (value is! String) {
      throw FluvieSpecError(
        'A palette value is a literal hex color like "#AARRGGBB"; tokens cannot reference tokens',
        path: [...path, entry.key],
      );
    }
    palette[entry.key] = decodeColor(value, path: [...path, entry.key]);
  }
  return palette;
}

Map<String, TextStyle> _parseTypeScale(Object? raw, List<String> path) {
  final entries = _tokenMap(raw, path);
  final typeScale = <String, TextStyle>{};
  for (final entry in entries.entries) {
    final value = entry.value;
    if (value is! Map<String, Object?>) {
      throw FluvieSpecError('Expected a style object', path: [...path, entry.key]);
    }
    if (value.containsKey('token') || value['color'] is Map) {
      throw FluvieSpecError(
        'A type scale style is fully literal; tokens cannot reference tokens',
        path: [...path, entry.key],
      );
    }
    typeScale[entry.key] = decodeTextStyle(value, path: [...path, entry.key]);
  }
  return typeScale;
}

Map<String, double> _parseSpacing(Object? raw, List<String> path) {
  final entries = _tokenMap(raw, path);
  final spacing = <String, double>{};
  for (final entry in entries.entries) {
    final value = entry.value;
    if (value is! num) {
      throw FluvieSpecError('Expected a number', path: [...path, entry.key]);
    }
    spacing[entry.key] = value.toDouble();
  }
  return spacing;
}

/// Checks [raw] is an object whose keys are all identifier token names and
/// returns it; an absent map reads as empty.
Map<String, Object?> _tokenMap(Object? raw, List<String> path) {
  if (raw == null) return const {};
  if (raw is! Map<String, Object?>) {
    throw FluvieSpecError('Expected an object of named tokens', path: path);
  }
  for (final name in raw.keys) {
    if (!_tokenName.hasMatch(name)) {
      throw FluvieSpecError(
        'Invalid token name "$name"; a token name is a letter followed by letters or digits',
        path: path,
      );
    }
  }
  return raw;
}
