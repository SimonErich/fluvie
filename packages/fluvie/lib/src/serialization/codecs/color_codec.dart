import 'package:flutter/painting.dart' show Color;
import 'package:fluvie/src/core/errors/fluvie_spec_error.dart';

/// The JSON form of a [Color]: a `"#AARRGGBB"` hex string — always eight
/// uppercase digits, so it round-trips byte for byte.
String encodeColor(Color color) =>
    '#${color.toARGB32().toRadixString(16).padLeft(8, '0').toUpperCase()}';

/// Reads a [Color] from a hex string in [raw].
///
/// Accepts `"#RRGGBB"` (taken as fully opaque) or `"#AARRGGBB"`. Throws a
/// [FluvieSpecError] (located at [path]) when [raw] is not a valid hex color.
Color decodeColor(Object? raw, {List<String> path = const []}) {
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
