/// Parses a human duration like `90s`, `30m`, `24h`, `7d`, or `500ms` into a
/// [Duration].
///
/// The grammar is a positive integer followed by one unit suffix
/// (`ms`/`s`/`m`/`h`/`d`). Throws a [FormatException] naming [label] for any
/// other input (empty, missing unit, non-integer, negative), so a misconfigured
/// env var fails loudly at startup rather than silently defaulting.
Duration parseHumanDuration(String value, {String label = 'duration'}) {
  final match = _pattern.firstMatch(value.trim());
  if (match == null) {
    throw FormatException(
      '$label must be <int><unit> with unit ms|s|m|h|d (e.g. "24h"), got "$value".',
    );
  }
  final amount = int.parse(match.group(1)!);
  return switch (match.group(2)!) {
    'ms' => Duration(milliseconds: amount),
    's' => Duration(seconds: amount),
    'm' => Duration(minutes: amount),
    'h' => Duration(hours: amount),
    _ => Duration(days: amount),
  };
}

final RegExp _pattern = RegExp(r'^(\d+)(ms|s|m|h|d)$');
