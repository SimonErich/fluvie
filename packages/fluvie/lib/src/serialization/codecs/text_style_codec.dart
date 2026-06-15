import 'package:flutter/painting.dart' show FontWeight, TextStyle;
import 'package:fluvie/src/core/errors/fluvie_spec_error.dart';
import 'package:fluvie/src/serialization/codecs/color_codec.dart';

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
/// `fontWeight`, `fontFamily`, `letterSpacing`, and `height` — only the fields
/// that are set.
Map<String, Object?> encodeTextStyle(TextStyle style) => {
  if (style.color != null) 'color': encodeColor(style.color!),
  if (style.fontSize != null) 'fontSize': style.fontSize,
  if (style.fontWeight != null) 'fontWeight': _weightName(style.fontWeight!),
  if (style.fontFamily != null) 'fontFamily': style.fontFamily,
  if (style.letterSpacing != null) 'letterSpacing': style.letterSpacing,
  if (style.height != null) 'height': style.height,
};

/// Reads a [TextStyle] from an object in [raw] (the [encodeTextStyle] subset).
///
/// Throws a [FluvieSpecError] (located at [path]) when [raw] is not an object or
/// names an unknown font weight.
TextStyle decodeTextStyle(Object? raw, {List<String> path = const []}) {
  if (raw is! Map<String, Object?>) {
    throw FluvieSpecError('Expected a text style object', path: path);
  }
  final color = raw['color'];
  final weight = raw['fontWeight'];
  final family = raw['fontFamily'];
  return TextStyle(
    color: color == null ? null : decodeColor(color, path: [...path, 'color']),
    fontSize: _double(raw['fontSize']),
    fontWeight: weight == null ? null : _decodeWeight(weight, [...path, 'fontWeight']),
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
