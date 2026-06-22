/// The severity of a [FluvieDiagnostic], mirroring the analyzer's three levels.
enum FluvieDiagnosticSeverity {
  /// A problem that prevents the code from compiling.
  error,

  /// A likely mistake that still compiles.
  warning,

  /// An informational note.
  info,
}

/// A single problem found in a Fluvie snippet, located 1-based for an editor.
///
/// [length] is the number of characters the problem spans from ([line],
/// [column]); [code] is the analyzer or lint rule name (e.g. `dangling_anchor`).
final class FluvieDiagnostic {
  /// Creates a diagnostic at a 1-based [line] and [column].
  const FluvieDiagnostic({
    required this.severity,
    required this.message,
    required this.line,
    required this.column,
    this.length,
    this.code,
  });

  /// How serious the problem is.
  final FluvieDiagnosticSeverity severity;

  /// The human-readable description.
  final String message;

  /// The 1-based line the problem starts on.
  final int line;

  /// The 1-based column the problem starts at.
  final int column;

  /// The number of characters the problem spans, when known.
  final int? length;

  /// The analyzer or lint rule code, when known.
  final String? code;
}
