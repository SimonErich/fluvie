import 'dart:io';

import 'package:fluvie_cli/fluvie_cli.dart' show fileHarnessSource;
import 'package:fluvie_server/src/api/render/code_import_policy.dart';
import 'package:fluvie_server/src/api/render/code_render_setup.dart';
import 'package:fluvie_server/src/api/render/render_runner.dart';
import 'package:test/test.dart';

const _goodCode = "import 'package:fluvie/fluvie.dart';\nVideo build() => throw 0;";

void main() {
  late Directory project;

  setUp(() {
    project = Directory.systemTemp.createTempSync('fluvie_setup_project_');
    addTearDown(() => project.deleteSync(recursive: true));
  });

  test('writes input.dart and harness_test.dart into a fresh per-render dir', () {
    final staged = stageCodeRender(projectDir: project.path, code: _goodCode);

    expect(File('${staged.dir.path}/input.dart').readAsStringSync(), _goodCode);
    final harness = File('${staged.dir.path}/harness_test.dart').readAsStringSync();
    expect(harness, contains("import 'input.dart' as target;"));
    expect(staged.dir.path, startsWith('${project.path}/.fluvie_playground/'));
  });

  test('generates the same harness the CLI does, so the two cannot drift', () {
    // The server no longer carries its own copy of the harness text: it calls
    // the CLI's template with the snippet as the target.
    final staged = stageCodeRender(projectDir: project.path, code: _goodCode);

    expect(
      File('${staged.dir.path}/harness_test.dart').readAsStringSync(),
      fileHarnessSource(targetImport: 'input.dart', timeout: codeRenderTimeout),
    );
  });

  test('the harness carries a bounded timeout, so a runaway build() is killed', () {
    // The difference from a trusted local render, which uses Timeout.none: an
    // untrusted snippet gets a ceiling `flutter test` enforces.
    final harness = File(
      '${stageCodeRender(projectDir: project.path, code: _goodCode).dir.path}/harness_test.dart',
    ).readAsStringSync();

    expect(
      harness,
      contains('timeout: const Timeout(Duration(seconds: ${codeRenderTimeout.inSeconds}))'),
    );
    expect(harness, isNot(contains('Timeout.none')));
  });

  test('the staged harness is ephemeral: two submissions never share a directory', () {
    expect(stageCodeRender(projectDir: project.path, code: _goodCode).ephemeral, isTrue);
  });

  test('the harness path is relative to the project root', () {
    final staged = stageCodeRender(projectDir: project.path, code: _goodCode);

    expect(staged.harnessPath, startsWith('.fluvie_playground/'));
    expect(staged.harnessPath, endsWith('/harness_test.dart'));
    expect(File('${project.path}/${staged.harnessPath}').existsSync(), isTrue);
  });

  test('two stagings never collide', () {
    final a = stageCodeRender(projectDir: project.path, code: _goodCode);
    final b = stageCodeRender(projectDir: project.path, code: _goodCode);
    expect(a.dir.path, isNot(b.dir.path));
  });

  test('cleanup deletes the staged directory', () {
    final staged = stageCodeRender(projectDir: project.path, code: _goodCode);
    expect(staged.dir.existsSync(), isTrue);

    staged.cleanup();

    expect(staged.dir.existsSync(), isFalse);
  });

  test('cleanup is a no-op when the directory is already gone', () {
    final staged = stageCodeRender(projectDir: project.path, code: _goodCode);
    staged.dir.deleteSync(recursive: true);

    expect(staged.cleanup, returnsNormally);
  });

  test('a disallowed import throws before any file is written', () {
    expect(
      () => stageCodeRender(projectDir: project.path, code: "import 'dart:io';"),
      throwsA(isA<CodeImportException>()),
    );
    expect(Directory('${project.path}/.fluvie_playground').existsSync(), isFalse);
  });

  group('stageCodeRenderOrFail', () {
    test('stages under the given render project', () {
      // The pubspec depending on fluvie that resolveProjectDir probes for.
      File('${project.path}/pubspec.yaml').writeAsStringSync('''
name: fluvie_example
dependencies:
  flutter:
    sdk: flutter
  fluvie: ^0.2.0
''');

      final staged = stageCodeRenderOrFail(renderProject: project.path, code: _goodCode);

      expect(File('${staged.dir.path}/input.dart').existsSync(), isTrue);
      staged.cleanup();
    });

    test('maps a disallowed import to a RenderFailure (not a CodeImportException)', () {
      expect(
        () => stageCodeRenderOrFail(renderProject: project.path, code: "import 'dart:io';"),
        throwsA(isA<RenderFailure>().having((e) => e.message, 'message', contains('dart:io'))),
      );
    });
  });
}
