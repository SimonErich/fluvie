part of 'dart_spec_printer.dart';

/// Joins the non-null argument fragments with ', ' — the body of a constructor
/// call, with omitted (defaulted) arguments already dropped.
String _args(List<String?> parts) => parts.whereType<String>().join(', ');

/// A `VideoSize` expression: a preset name, or `VideoSize(w, h)` for explicit
/// dimensions.
String _videoSize(Object? size) {
  if (size is String) return 'VideoSize.$size';
  final map = _map(size);
  return 'VideoSize(${map['width']}, ${map['height']})';
}

/// A `Color(0x...)` from a `#RRGGBB`/`#AARRGGBB` hex string; the canonical spec
/// form is eight upper-hex digits, opaque six-digit forms gain an `FF` alpha.
String _color(Object? hex) {
  final text = hex! as String;
  var digits = text.startsWith('#') ? text.substring(1) : text;
  if (digits.length == 6) digits = 'FF$digits';
  return 'Color(0x${digits.toUpperCase()})';
}

/// Time sugar from a unit-tagged string: `30.frames`, `2.5.seconds`, `500.ms`,
/// `0.3.relative`, or `Time.relative(f, max: ...)` for the capped form.
String _time(String raw) {
  final text = raw.trim();
  final relative = text.indexOf('r');
  if (relative > 0) {
    final fraction = text.substring(0, relative);
    final rest = text.substring(relative + 1);
    if (rest.isEmpty) return '${_numLit(fraction)}.relative';
    if (rest.startsWith('@')) {
      return 'Time.relative(${_numLit(fraction)}, max: ${_time(rest.substring(1))})';
    }
    throw FormatException('Invalid relative time "$raw"');
  }
  if (text.endsWith('ms')) return '${text.substring(0, text.length - 2)}.ms';
  if (text.endsWith('f')) return '${text.substring(0, text.length - 1)}.frames';
  if (text.endsWith('s')) return '${_numLit(text.substring(0, text.length - 1))}.seconds';
  throw FormatException('Unrecognized time "$raw"');
}

/// An `Ease.<name>` value; the reserved `in` maps to the `in_` member.
String _ease(String name) => name == 'in' ? 'Ease.in_' : 'Ease.$name';

/// A typed enum value, e.g. `BoxFit.cover`, from its `.name`.
String _enumValue(String type, String name) => '$type.$name';

/// An `Alignment` value: a named alignment, or `Alignment(x, y)`.
String _alignment(Object? raw) {
  if (raw is String) return 'Alignment.$raw';
  final map = _map(raw);
  return 'Alignment(${_num(map['x'])}, ${_num(map['y'])})';
}

/// A numeric literal for a JSON number; rejects non-finite values so the output
/// can never contain `Infinity`/`NaN`.
String _num(Object? value) {
  if (value is int) return value.toString();
  if (value is double) {
    if (!value.isFinite) throw FormatException('Non-finite number: $value');
    return value.toString();
  }
  throw FormatException('Expected a number, got $value');
}

/// Formats the numeric part of a time string: drops a redundant `.0` so whole
/// values read as `4`, while preserving the exact text of fractions like `2.5`.
String _numLit(String raw) {
  final value = double.tryParse(raw);
  if (value == null) return raw;
  if (value.isFinite && value == value.truncateToDouble()) return value.truncate().toString();
  return raw;
}

/// A safe single-quoted Dart string literal for an author-supplied [value].
///
/// Backslash, the quote, and `$` (Dart interpolation) are escaped, control
/// characters and the line/paragraph separators become `\u{..}`, so no input can
/// terminate the literal or inject an expression.
String _str(String value) {
  final buffer = StringBuffer("'");
  for (final rune in value.runes) {
    switch (rune) {
      case 0x5C:
        buffer.write(r'\\');
      case 0x27:
        buffer.write(r"\'");
      case 0x24:
        buffer.write(r'\$');
      case 0x0A:
        buffer.write(r'\n');
      case 0x0D:
        buffer.write(r'\r');
      case 0x09:
        buffer.write(r'\t');
      case 0x08:
        buffer.write(r'\b');
      case 0x0C:
        buffer.write(r'\f');
      case 0x0B:
        buffer.write(r'\v');
      default:
        if (rune < 0x20 || rune == 0x7F || rune == 0x2028 || rune == 0x2029) {
          buffer.write('\\u{${rune.toRadixString(16)}}');
        } else {
          buffer.writeCharCode(rune);
        }
    }
  }
  buffer.write("'");
  return buffer.toString();
}
