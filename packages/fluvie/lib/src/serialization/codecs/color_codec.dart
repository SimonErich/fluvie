import 'package:flutter/painting.dart' show Color;
import 'package:fluvie/src/core/errors/fluvie_spec_error.dart';
import 'package:fluvie/src/serialization/theme_spec.dart';

/// The JSON form of a [Color]: a `"#AARRGGBB"` hex string — always eight
/// uppercase digits, so it round-trips byte for byte.
String encodeColor(Color color) =>
    '#${color.toARGB32().toRadixString(16).padLeft(8, '0').toUpperCase()}';

/// Reads a [Color] from a hex string in [raw], or resolves a
/// `{"token": "<name>"}` reference against the [ThemeSpec] in scope.
///
/// Accepts `"#RRGGBB"` (taken as fully opaque) or `"#AARRGGBB"`. Throws a
/// [FluvieSpecError] (located at [path]) when [raw] is not a valid hex color,
/// or when a token reference is malformed, names no palette entry, or no
/// theme is in scope (see [ThemeSpec.resolve]).
Color decodeColor(Object? raw, {List<String> path = const []}) {
  if (raw is Map<String, Object?>) return _tokenColor(raw, path);
  if (raw is! String || !raw.startsWith('#')) {
    throw FluvieSpecError('Expected a hex color like "#RRGGBB" or "#AARRGGBB"', path: path);
  }
  var hex = raw.substring(1);
  if (hex.length == 6) hex = 'FF$hex';
  if (hex.length != 8) {
    throw FluvieSpecError('Hex color must be #RRGGBB or #AARRGGBB, got "$raw"', path: path);
  }
  final value = int.tryParse(hex, radix: 16);
  if (value == null) {
    throw FluvieSpecError('Invalid hex color "$raw"', path: path);
  }
  return Color(value);
}

/// A color token reference: the closed `{"token": "<name>"}` shape, resolved
/// against the palette of the theme in scope.
Color _tokenColor(Map<String, Object?> raw, List<String> path) {
  final token = raw['token'];
  if (token is! String || raw.length != 1) {
    throw FluvieSpecError('A color token reference is exactly {"token": "<name>"}', path: path);
  }
  final theme = ThemeSpec.current;
  if (theme == null) {
    throw FluvieSpecError(
      'Color token "$token" cannot resolve: no theme is in scope. '
      'Declare a top-level "theme" with a "palette"',
      path: path,
    );
  }
  return theme.paletteColor(token, path: path);
}
