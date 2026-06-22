import 'package:fluvie_server/src/api/validate/code_diagnostic.dart';

export 'package:fluvie_server/src/api/validate/code_diagnostic.dart';

/// The outcome of validating a code snippet: every problem found in
/// [diagnostics], and whether the snippet is render-[ok].
final class CodeValidationResult {
  /// Creates a result from its [diagnostics].
  const CodeValidationResult(this.diagnostics);

  /// Every problem found, in no particular order.
  final List<CodeDiagnostic> diagnostics;

  /// True when no diagnostic is an error, so the snippet is safe to render.
  /// Warnings and infos are reported but do not block.
  bool get ok => !diagnostics.any((d) => d.severity == CodeDiagnosticSeverity.error);

  /// This result as the validate endpoint's JSON body.
  Map<String, Object?> toJson() => {
    'ok': ok,
    'diagnostics': [for (final diagnostic in diagnostics) diagnostic.toJson()],
  };
}
