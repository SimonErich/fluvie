import 'dart:io';

import 'package:fluvie_cli/src/process_runner.dart';
import 'package:test/test.dart';

void main() {
  group('IoProcessRunner', () {
    test('runs the Dart VM hermetically and collects stdout', () async {
      const runner = IoProcessRunner();

      final result = await runner.run(Platform.resolvedExecutable, const ['--version']);

      expect(result.exitCode, 0);
      expect('${result.stdout}${result.stderr}', isNotEmpty);
    });

    test('honors the working directory', () async {
      const runner = IoProcessRunner();
      final dir = Directory.systemTemp.createTempSync('fluvie_cli_runner_');
      addTearDown(() => dir.deleteSync(recursive: true));

      final result = await runner.run(Platform.resolvedExecutable, const [
        '--version',
      ], workingDirectory: dir.path);

      expect(result.exitCode, 0);
    });

    test('adds the given environment on top of the inherited one', () async {
      const runner = IoProcessRunner();
      final dir = Directory.systemTemp.createTempSync('fluvie_cli_env_');
      addTearDown(() => dir.deleteSync(recursive: true));
      final script = File('${dir.path}/echo_env.dart')
        ..writeAsStringSync(
          "import 'dart:io';\n"
          "void main() => stdout.write(Platform.environment['FLUVIE_TEST_ENV'] ?? 'MISSING');\n",
        );

      final result = await runner.run(
        Platform.resolvedExecutable,
        [script.path],
        environment: const {'FLUVIE_TEST_ENV': 'hello-env'},
      );

      // The child inherits PATH etc. and additionally sees FLUVIE_TEST_ENV.
      expect(result.exitCode, 0, reason: '${result.stdout}${result.stderr}');
      expect(result.stdout, contains('hello-env'));
    });
  });

  group('ProcessRunResult', () {
    test('carries exit code, stdout and stderr', () {
      const result = ProcessRunResult(exitCode: 3, stdout: 'a', stderr: 'b');
      expect(result.exitCode, 3);
      expect(result.stdout, 'a');
      expect(result.stderr, 'b');
    });
  });
}
