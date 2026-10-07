import 'dart:io';

import 'package:fluvie_validate/fluvie_validate.dart';
import 'package:test/test.dart';

void main() {
  final analyzer = FluvieCodeAnalyzer(projectRoot: Directory.current);
  tearDownAll(analyzer.dispose);

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
  Trigger.whenEnds(a);
  return Video(scenes: const []);
}
''');

    expect(diagnostics.any((d) => d.code == 'dangling_anchor'), isTrue);
  });

  test(
    'original file preserves relative imports and refreshes edited code without scratch writes',
    () async {
      final directory = Directory('${Directory.current.path}/test/file_validation_fixture')
        ..createSync();
      final dependency = File('${directory.path}/helper.dart')
        ..writeAsStringSync('int count() => 3;\n');
      final file = File('${directory.path}/story.dart')
        ..writeAsStringSync("import 'helper.dart';\nint total() => count();\n");
      try {
        expect(errorsIn(await analyzer.analyzeFile(file.path)), isEmpty);
        file.writeAsStringSync("import 'helper.dart';\nint total() => missing();\n");
        final diagnostics = await analyzer.analyzeFile(file.path);
        final error = errorsIn(diagnostics).single;
        expect(error.line, 2);
        expect(error.toJson(), containsPair('code', 'UNDEFINED_FUNCTION'));
        expect(error.toString(), contains('error at 2:'));
        expect(
          directory.listSync().map((entry) => entry.path).toList()..sort(),
          [dependency.path, file.path]..sort(),
        );
      } finally {
        directory.deleteSync(recursive: true);
      }
    },
  );
  test('simultaneous requests keep isolated diagnostics and recover after failure', () async {
    final results = await Future.wait([
      analyzer.analyze('int value() => 1;'),
      analyzer.analyze('int value() => unknown();'),
    ]);
    expect(errorsIn(results.first), isEmpty);
    expect(errorsIn(results.last), hasLength(1));
    await expectLater(analyzer.analyzeFile('missing.dart'), throwsA(isA<FileSystemException>()));
    expect(errorsIn(await analyzer.analyze('int value() => 2;')), isEmpty);
  });
}
