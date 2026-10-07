import 'dart:ui' show Path;

/// Builds a [Path] from a small, absolute SVG path-data subset — the spec's
/// serialized form for `Shape.path` geometry.
///
/// Supported commands (absolute only, each followed by exactly its
/// coordinates; separators are whitespace or commas):
///
/// - `M x y` — start a new subpath
/// - `L x y` — line to
/// - `H x` / `V y` — horizontal / vertical line from the current point
/// - `C x1 y1 x2 y2 x y` — cubic curve
/// - `Q x1 y1 x y` — quadratic curve
/// - `Z` — close the subpath
///
/// Throws a [FormatException] naming the problem for anything else — an
/// unknown command, missing coordinates, or a non-numeric token. The string
/// is data the editor writes and the printer re-emits verbatim, so the
/// subset stays deliberately small and unambiguous.
Path pathFromSvg(String data) {
  final tokens = data.trim().split(RegExp(r'[\s,]+'));
  if (tokens.length == 1 && tokens.single.isEmpty) {
    throw const FormatException('An SVG path needs at least one "M x y" command.');
  }
  final path = Path();
  var index = 0;
  var started = false;
  var x = 0.0;
  var y = 0.0;

  double number() {
    if (index >= tokens.length) {
      throw FormatException('SVG path data ended while expecting a coordinate: "$data"');
    }
    final token = tokens[index++];
    final value = double.tryParse(token);
    if (value == null) {
      throw FormatException('Expected a number in SVG path data, found "$token".');
    }
    return value;
  }

  while (index < tokens.length) {
    final command = tokens[index++];
    if (command != 'M' && !started) {
      throw FormatException('An SVG path must start with "M", found "$command".');
    }
    switch (command) {
      case 'M':
        x = number();
        y = number();
        path.moveTo(x, y);
        started = true;
      case 'L':
        x = number();
        y = number();
        path.lineTo(x, y);
      case 'H':
        x = number();
        path.lineTo(x, y);
      case 'V':
        y = number();
        path.lineTo(x, y);
      case 'C':
        final x1 = number();
        final y1 = number();
        final x2 = number();
        final y2 = number();
        x = number();
        y = number();
        path.cubicTo(x1, y1, x2, y2, x, y);
      case 'Q':
        final x1 = number();
        final y1 = number();
        x = number();
        y = number();
        path.quadraticBezierTo(x1, y1, x, y);
      case 'Z':
        path.close();
      default:
        throw FormatException('Unknown SVG path command "$command".');
    }
  }
  return path;
}
