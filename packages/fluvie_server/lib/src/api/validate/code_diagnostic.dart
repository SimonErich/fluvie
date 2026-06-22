/// The severity of a [CodeDiagnostic], mirroring the analyzer's three levels.
enum CodeDiagnosticSeverity {
  /// A problem that prevents the code from compiling or rendering.
  error,

  /// A likely mistake that still compiles.
  warning,

  /// An informational lint or style note.
  info,
}

/// A single problem found in submitted code, located for an editor to mark.
///
/// Positions are 1-based. [length] is the number of characters the problem
/// spans from ([line], [column]); [code] is the analyzer or lint rule name.
final class CodeDiagnostic {
  /// Creates a diagnostic at a 1-based [line] and [column].
  const CodeDiagnostic({
    required this.severity,
    required this.message,
    required this.line,
    required this.column,
    this.length,
    this.code,
  });

  /// How serious the problem is.
  final CodeDiagnosticSeverity severity;

  /// The human-readable description.
  final String message;

  /// The 1-based line the problem starts on.
  final int line;

  /// The 1-based column the problem starts at.
  final int column;

  /// The number of characters the problem spans, when known.
  final int? length;

  /// The analyzer or lint rule code (e.g. `undefined_identifier`), when known.
  final String? code;

  /// This diagnostic as a JSON map for the validate response.
  Map<String, Object?> toJson() => {
    'severity': severity.name,
    'message': message,
    'line': line,
    'column': column,
    if (length != null) 'length': length,
    if (code != null) 'code': code,
  };
}
