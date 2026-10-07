import 'package:flutter/painting.dart' show FontStyle, FontWeight, TextStyle;
import 'package:fluvie/src/core/errors/fluvie_spec_error.dart';
import 'package:fluvie/src/serialization/codecs/color_codec.dart';
import 'package:fluvie/src/serialization/theme_spec.dart';

/// The font weights the spec understands, by name (`w100`..`w900`).
const Map<String, FontWeight> namedFontWeights = {
  'w100': FontWeight.w100,
  'w200': FontWeight.w200,
  'w300': FontWeight.w300,
  'w400': FontWeight.w400,
  'w500': FontWeight.w500,
  'w600': FontWeight.w600,
  'w700': FontWeight.w700,
  'w800': FontWeight.w800,
  'w900': FontWeight.w900,
};

/// The JSON form of a curated [TextStyle] subset: `color`, `fontSize`,
/// `fontWeight`, `fontStyle`, `fontFamily`, `letterSpacing`, and `height` — only the fields
/// that are set.
Map<String, Object?> encodeTextStyle(TextStyle style) => {
  if (style.color != null) 'color': encodeColor(style.color!),
  if (style.fontSize != null) 'fontSize': style.fontSize,
  if (style.fontWeight != null) 'fontWeight': _weightName(style.fontWeight!),
  if (style.fontStyle != null) 'fontStyle': style.fontStyle!.name,
  if (style.fontFamily != null) 'fontFamily': style.fontFamily,
  if (style.letterSpacing != null) 'letterSpacing': style.letterSpacing,
  if (style.height != null) 'height': style.height,
};

/// Reads a [TextStyle] from an object in [raw] (the [encodeTextStyle] subset).
///
/// A `"token"` key adopts the whole type-scale entry of that name from the
/// [ThemeSpec] in scope as the base; sibling literal fields win per field.
/// Throws a [FluvieSpecError] (located at [path]) when [raw] is not an object,
/// names an unknown font weight, or carries a token that cannot resolve.
TextStyle decodeTextStyle(Object? raw, {List<String> path = const []}) {
  if (raw is! Map<String, Object?>) {
    throw FluvieSpecError('Expected a text style object', path: path);
  }
  final token = raw['token'];
  if (token != null) return _tokenStyle(token, raw, path);
  return _literalStyle(raw, path);
}

/// A style with a type-scale `token` base: the named entry merged under the
/// sibling literal fields, so a literal always wins per field.
TextStyle _tokenStyle(Object? token, Map<String, Object?> raw, List<String> path) {
  if (token is! String) {
    throw FluvieSpecError('Expected a string "token"', path: [...path, 'token']);
  }
  final theme = ThemeSpec.current;
  if (theme == null) {
    throw FluvieSpecError(
      'Style token "$token" cannot resolve: no theme is in scope. '
      'Declare a top-level "theme" with a "typeScale"',
      path: path,
    );
  }
  return theme.typeScaleStyle(token, path: path).merge(_literalStyle(raw, path));
}

TextStyle _literalStyle(Map<String, Object?> raw, List<String> path) {
  final color = raw['color'];
  final weight = raw['fontWeight'];
  final family = raw['fontFamily'];
  return TextStyle(
    color: color == null ? null : decodeColor(color, path: [...path, 'color']),
    fontSize: _double(raw['fontSize']),
    fontWeight: weight == null ? null : _decodeWeight(weight, [...path, 'fontWeight']),
    fontStyle: raw['fontStyle'] == null
        ? null
        : _decodeFontStyle(raw['fontStyle'], [...path, 'fontStyle']),
    fontFamily: family is String ? family : null,
    letterSpacing: _double(raw['letterSpacing']),
    height: _double(raw['height']),
  );
}

String _weightName(FontWeight weight) =>
    namedFontWeights.entries.firstWhere((entry) => entry.value == weight).key;

FontWeight _decodeWeight(Object? raw, List<String> path) {
  if (raw == 'bold') return FontWeight.bold;
  if (raw == 'normal') return FontWeight.normal;
  if (raw is String) {
    final weight = namedFontWeights[raw];
    if (weight != null) return weight;
  }
  throw FluvieSpecError('Unknown font weight "$raw"; use w100..w900, bold, or normal', path: path);
}

double? _double(Object? value) => value is num ? value.toDouble() : null;

FontStyle _decodeFontStyle(Object? raw, List<String> path) => switch (raw) {
  'normal' => FontStyle.normal,
  'italic' => FontStyle.italic,
  _ => throw FluvieSpecError('Unknown font style "$raw"; use normal or italic', path: path),
};
