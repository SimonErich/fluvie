import 'dart:io';

import 'package:fluvie_server/src/api/validate/code_validation_result.dart';
import 'package:fluvie_server/src/api/validate/code_validation_service.dart';
import 'package:fluvie_validate/fluvie_validate.dart';

/// A [CodeValidationService] backed by the in-process [FluvieCodeAnalyzer].
///
/// It resolves the snippet against `package:fluvie` and runs the fluvie_lints
/// rules at the configured project root — analysis only; the code is never
/// executed.
final class InProcessCodeValidationService implements CodeValidationService {
  /// Creates the service, rooting snippet resolution at [projectRoot] (a
  /// directory inside a package that resolves `package:fluvie`).
  InProcessCodeValidationService({required Directory projectRoot})
    : _analyzer = FluvieCodeAnalyzer(projectRoot: projectRoot);

  final FluvieCodeAnalyzer _analyzer;

  @override
  Future<CodeValidationResult> validate(String code) async {
    final diagnostics = await _analyzer.analyze(code);
    return CodeValidationResult([for (final diagnostic in diagnostics) _map(diagnostic)]);
  }

  CodeDiagnostic _map(FluvieDiagnostic diagnostic) => CodeDiagnostic(
    severity: _severityFor(diagnostic.severity),
    message: diagnostic.message,
    line: diagnostic.line,
    column: diagnostic.column,
    length: diagnostic.length,
    code: diagnostic.code,
  );

  CodeDiagnosticSeverity _severityFor(FluvieDiagnosticSeverity severity) => switch (severity) {
    FluvieDiagnosticSeverity.error => CodeDiagnosticSeverity.error,
    FluvieDiagnosticSeverity.warning => CodeDiagnosticSeverity.warning,
    FluvieDiagnosticSeverity.info => CodeDiagnosticSeverity.info,
  };
}
