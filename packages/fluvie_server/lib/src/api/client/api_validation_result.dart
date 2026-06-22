import 'package:meta/meta.dart';

/// The severity of an [ApiCodeDiagnostic], mirroring the server's three levels.
enum ApiDiagnosticSeverity {
  /// A problem that prevents the code from compiling or rendering.
  error,

  /// A likely mistake that still compiles.
  warning,

  /// An informational note.
  info,
}

/// One problem the validate endpoint reported, located 1-based for an editor.
@immutable
final class ApiCodeDiagnostic {
  /// Creates a diagnostic at a 1-based [line] and [column].
  const ApiCodeDiagnostic({
    required this.severity,
    required this.message,
    required this.line,
    required this.column,
    this.length,
    this.code,
  });

  /// Reads a diagnostic from its decoded JSON [json].
  factory ApiCodeDiagnostic.fromJson(Map<String, Object?> json) => ApiCodeDiagnostic(
    severity: _severity(json['severity']),
    message: json['message'] as String? ?? '',
    line: (json['line'] as num?)?.toInt() ?? 1,
    column: (json['column'] as num?)?.toInt() ?? 1,
    length: (json['length'] as num?)?.toInt(),
    code: json['code'] as String?,
  );

  /// How serious the problem is.
  final ApiDiagnosticSeverity severity;

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

  static ApiDiagnosticSeverity _severity(Object? raw) => switch (raw) {
    'error' => ApiDiagnosticSeverity.error,
    'warning' => ApiDiagnosticSeverity.warning,
    _ => ApiDiagnosticSeverity.info,
  };
}

/// The result of `POST /v1/validate`: whether the code is render-[ok] and every
/// diagnostic found.
@immutable
final class ApiValidationResult {
  /// Creates a result.
  const ApiValidationResult({required this.ok, required this.diagnostics});

  /// Reads a result from its decoded JSON [json].
  factory ApiValidationResult.fromJson(Map<String, Object?> json) => ApiValidationResult(
    ok: json['ok'] as bool? ?? false,
    diagnostics: [
      for (final diagnostic in (json['diagnostics'] as List? ?? const []))
        ApiCodeDiagnostic.fromJson(diagnostic as Map<String, Object?>),
    ],
  );

  /// True when no diagnostic is an error, so the snippet is safe to render.
  final bool ok;

  /// Every problem found, in source order.
  final List<ApiCodeDiagnostic> diagnostics;
}
