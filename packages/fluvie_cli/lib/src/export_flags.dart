/// The validated export flags threaded into the capture defines: the aspect,
/// encode quality, export format, and poster Time string (each `null` when its
/// flag was not given).
typedef ExportFlags = ({String? aspect, String? quality, String? format, String? poster});

/// The valid `--aspect` values (the `Aspect` enum names).
///
/// Mirrored here because the CLI is pure Dart and cannot import the Flutter
/// `fluvie` package; the harness validates the define against the real enum.
const List<String> aspectNames = ['reels', 'square', 'landscape', 'portrait45'];

/// The valid `--quality` values (the `Quality` enum names).
const List<String> qualityNames = ['low', 'medium', 'high', 'max'];

/// The valid `--format` values (the `ExportMode` names).
const List<String> formatNames = ['mp4', 'gif', 'imageSequence', 'transparent'];

/// Returns [value] when it is one of [allowed], or throws a [UsageFailure]
/// naming [flag] and the valid set (a bad enum is exit 64).
///
/// A `null` [value] passes through unchanged (the flag was not given).
String? validateEnumFlag(String? value, {required String flag, required List<String> allowed}) {
  if (value == null) return null;
  if (!allowed.contains(value)) {
    throw UsageFailure('$flag must be one of ${allowed.join(', ')}, got "$value".');
  }
  return value;
}

/// Returns the non-empty poster [value], or throws a [UsageFailure] when it is
/// the empty string. The Time string itself is parsed harness-side.
String? validatePoster(String? value, {required String flag}) {
  if (value == null) return null;
  if (value.isEmpty) {
    throw UsageFailure('$flag needs a non-empty Time string (e.g. "1.5s", "30f", "500ms").');
  }
  return value;
}

/// A misuse of the command line: surfaced as exit code 64 (BSD `EX_USAGE`),
/// distinct from an operational `CliFailure` (exit 1).
final class UsageFailure implements Exception {
  /// Creates a usage failure carrying [message].
  const UsageFailure(this.message);

  /// What was wrong with the command line, ready to print to stderr.
  final String message;

  @override
  String toString() => message;
}
