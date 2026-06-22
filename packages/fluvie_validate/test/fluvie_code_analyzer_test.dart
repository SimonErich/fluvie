import 'dart:io';

import 'package:fluvie_validate/fluvie_validate.dart';
import 'package:test/test.dart';

void main() {
  final analyzer = FluvieCodeAnalyzer(projectRoot: Directory.current);

  Iterable<FluvieDiagnostic> errorsIn(List<FluvieDiagnostic> diagnostics) =>
      diagnostics.where((d) => d.severity == FluvieDiagnosticSeverity.error);

  test('reports no errors for a valid composition', () async {
    final diagnostics = await analyzer.analyze('''
import 'package:fluvie/fluvie.dart';

Video build() => Video(scenes: const []);
''');

    expect(errorsIn(diagnostics), isEmpty);
  });

  test('flags an unresolved identifier at its line with a code', () async {
    final diagnostics = await analyzer.analyze('''
import 'package:fluvie/fluvie.dart';

Video build() => Vid(scenes: const []);
''');

    final errors = errorsIn(diagnostics).toList();
    expect(errors, isNotEmpty);
    expect(errors.any((e) => e.line == 3), isTrue);
    expect(errors.every((e) => e.code != null), isTrue);
  });

  test('flags a syntax error', () async {
    final diagnostics = await analyzer.analyze(
      "import 'package:fluvie/fluvie.dart';\nVideo build() => Video(scenes: [);",
    );

    expect(errorsIn(diagnostics), isNotEmpty);
  });

  test('runs the fluvie_lints rules (dangling anchor fires)', () async {
    final diagnostics = await analyzer.analyze('''
import 'package:fluvie/fluvie.dart';

Video build() {
  final a = Anchor();
  Trigger.after(a);
  return Video(scenes: const []);
}
''');

    expect(diagnostics.any((d) => d.code == 'dangling_anchor'), isTrue);
  });
}
