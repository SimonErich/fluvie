import 'dart:io';

import 'package:fluvie_server/src/api/validate/code_validation_result.dart';
import 'package:fluvie_server/src/api/validate/in_process_code_validation_service.dart';
import 'package:test/test.dart';

void main() {
  // The workspace root package_config (shared across the native workspace)
  // resolves `package:fluvie` for any file under a workspace package.
  final service = InProcessCodeValidationService(projectRoot: Directory.current);

  test('reports ok for a valid composition', () async {
    final result = await service.validate('''
import 'package:fluvie/fluvie.dart';

Video build() => Video(scenes: const []);
''');

    expect(result.ok, isTrue);
  });

  test('maps an analyzer error into a located CodeDiagnostic', () async {
    final result = await service.validate('''
import 'package:fluvie/fluvie.dart';

Video build() => Vid(scenes: const []);
''');

    expect(result.ok, isFalse);
    final error = result.diagnostics.firstWhere(
      (d) => d.severity == CodeDiagnosticSeverity.error,
    );
    expect(error.line, 3);
    expect(error.code, isNotNull);
  });
}
