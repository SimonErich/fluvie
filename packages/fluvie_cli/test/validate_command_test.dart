import 'dart:convert';
import 'dart:io';

import 'package:fluvie_cli/src/validate_command.dart';
import 'package:fluvie_validate/fluvie_validate.dart';
import 'package:path/path.dart' as p;
import 'package:test/test.dart';

void main() {
  late Directory project;
  setUp(() {
    project = Directory.systemTemp.createTempSync('fluvie_validate_command_');
    File(p.join(project.path, 'pubspec.yaml')).writeAsStringSync('name: cat_story\n');
    Directory(p.join(project.path, 'lib')).createSync();
    File(p.join(project.path, 'lib', 'story.dart')).writeAsStringSync('void build() {}\n');
  });
  tearDown(() => project.deleteSync(recursive: true));

  test('structured diagnostics retain original path, locations and error codes', () async {
    final out = StringBuffer();
    final file = p.join(project.path, 'lib', 'story.dart');
    final command = ValidateCommand(
      validator: (target) async {
        expect(target.path, file);
        expect(target.projectDir, project.path);
        return const [
          FluvieDiagnostic(
            severity: FluvieDiagnosticSeverity.error,
            message: 'Unknown widget',
            line: 4,
            column: 3,
            length: 6,
            code: 'undefined_identifier',
          ),
        ];
      },
    );
    expect(
      await command.execute(
        ValidateCommand.buildParser().parse([file, '--json']),
        out: out,
        err: StringBuffer(),
      ),
      1,
    );
    final report = jsonDecode(out.toString()) as Map;
    expect(report['path'], file);
    expect((report['diagnostics'] as List).single, {
      'severity': 'error',
      'message': 'Unknown widget',
      'line': 4,
      'column': 3,
      'length': 6,
      'code': 'undefined_identifier',
    });
  });

  test('warnings preserve successful static validation and readable output', () async {
    final out = StringBuffer();
    final file = p.join(project.path, 'lib', 'story.dart');
    final command = ValidateCommand(
      validator: (_) async => const [
        FluvieDiagnostic(
          severity: FluvieDiagnosticSeverity.warning,
          message: 'Unused value',
          line: 2,
          column: 8,
        ),
      ],
    );
    expect(
      await command.execute(
        ValidateCommand.buildParser().parse([file]),
        out: out,
        err: StringBuffer(),
      ),
      0,
    );
    expect(out.toString(), contains('$file:2:8: warning: Unused value'));
  });

  test('missing sources fail as structured errors and bad usage returns 64', () async {
    final out = StringBuffer();
    expect(
      await const ValidateCommand().execute(
        ValidateCommand.buildParser().parse([
          p.join(project.path, 'lib', 'missing.dart'),
          '--json',
        ]),
        out: out,
        err: StringBuffer(),
      ),
      1,
    );
    expect((jsonDecode(out.toString()) as Map)['error'], contains('No such composition file'));
    expect(
      await const ValidateCommand().execute(
        ValidateCommand.buildParser().parse([]),
        out: StringBuffer(),
        err: StringBuffer(),
      ),
      64,
    );
  });
}
