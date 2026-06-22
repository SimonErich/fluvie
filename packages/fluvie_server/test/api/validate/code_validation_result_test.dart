import 'package:fluvie_server/src/api/validate/code_validation_result.dart';
import 'package:test/test.dart';

void main() {
  group('CodeDiagnostic.toJson', () {
    test('omits length and code when they are null', () {
      const diagnostic = CodeDiagnostic(
        severity: CodeDiagnosticSeverity.warning,
        message: 'Unused import.',
        line: 1,
        column: 1,
      );

      expect(diagnostic.toJson(), {
        'severity': 'warning',
        'message': 'Unused import.',
        'line': 1,
        'column': 1,
      });
    });

    test('includes length and code when present', () {
      const diagnostic = CodeDiagnostic(
        severity: CodeDiagnosticSeverity.info,
        message: 'Prefer const.',
        line: 7,
        column: 3,
        length: 9,
        code: 'prefer_const_constructors',
      );

      expect(diagnostic.toJson(), {
        'severity': 'info',
        'message': 'Prefer const.',
        'line': 7,
        'column': 3,
        'length': 9,
        'code': 'prefer_const_constructors',
      });
    });
  });

  group('CodeValidationResult.ok', () {
    test('is true for no diagnostics', () {
      expect(const CodeValidationResult([]).ok, isTrue);
    });

    test('is true when only warnings and infos are present', () {
      const result = CodeValidationResult([
        CodeDiagnostic(
          severity: CodeDiagnosticSeverity.warning,
          message: 'w',
          line: 1,
          column: 1,
        ),
        CodeDiagnostic(severity: CodeDiagnosticSeverity.info, message: 'i', line: 2, column: 1),
      ]);

      expect(result.ok, isTrue);
      expect(result.toJson()['ok'], isTrue);
      expect(result.toJson()['diagnostics']! as List, hasLength(2));
    });

    test('is false when any diagnostic is an error', () {
      const result = CodeValidationResult([
        CodeDiagnostic(severity: CodeDiagnosticSeverity.warning, message: 'w', line: 1, column: 1),
        CodeDiagnostic(severity: CodeDiagnosticSeverity.error, message: 'e', line: 3, column: 1),
      ]);

      expect(result.ok, isFalse);
      expect(result.toJson()['ok'], isFalse);
    });
  });
}
