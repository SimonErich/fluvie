import 'dart:io';

import 'package:fluvie_cli/src/list_command.dart';
import 'package:fluvie_cli/src/process_runner.dart';
import 'package:mocktail/mocktail.dart';
import 'package:test/test.dart';

class _MockProcessRunner extends Mock implements ProcessRunner {}

void main() {
  late _MockProcessRunner runner;
  late StringBuffer out;
  late StringBuffer err;

  setUp(() {
    runner = _MockProcessRunner();
    out = StringBuffer();
    err = StringBuffer();
  });

  ListCommand command() => ListCommand(runner: runner);

  Future<int> execute(List<String> args) async =>
      command().execute(ListCommand.buildParser().parse(args), out: out, err: err);

  void stubList({int exitCode = 0, String stdout = '', String stderr = ''}) {
    when(
      () => runner.run('flutter', any(), workingDirectory: any(named: 'workingDirectory')),
    ).thenAnswer((_) async => ProcessRunResult(exitCode: exitCode, stdout: stdout, stderr: stderr));
  }

  test('runs the harness in list mode and prints the parsed keys', () async {
    stubList(stdout: 'noise\nfluvie-keys: demo, multi_scene, 04_scenes\nmore noise');

    final code = await execute(['--project', 'example']);

    expect(code, 0, reason: err.toString());
    expect(out.toString(), contains('demo'));
    expect(out.toString(), contains('multi_scene'));
    expect(out.toString(), contains('04_scenes'));
  });

  test('drives the harness with the list dart-define', () async {
    stubList(stdout: 'fluvie-keys: demo');

    await execute(['--project', 'example']);

    final captured =
        verify(
              () => runner.run(
                'flutter',
                captureAny(),
                workingDirectory: any(named: 'workingDirectory'),
              ),
            ).captured.single
            as List<String>;
    expect(captured, contains('--dart-define=FLUVIE_RENDER_LIST=true'));
    expect(captured, contains('test/render/capture_harness_test.dart'));
  });

  test('a failing harness run is a CliFailure (exit 1)', () async {
    stubList(exitCode: 1, stderr: 'boom');

    final code = await execute(['--project', 'example']);

    expect(code, 1);
    expect(err.toString(), isNotEmpty);
  });

  test('a missing keys line reports that none were found', () async {
    stubList(stdout: 'no marker here');

    final code = await execute(['--project', 'example']);

    expect(code, 1);
    expect(err.toString(), contains('fluvie-keys'));
  });

  test('a missing flutter binary fails with an install hint, not a raw exception', () async {
    when(
      () => runner.run('flutter', any(), workingDirectory: any(named: 'workingDirectory')),
    ).thenThrow(const ProcessException('flutter', ['test'], 'No such file or directory'));

    final code = await execute(['--project', 'example']);

    expect(code, 1);
    expect(err.toString(), contains('PATH'));
  });

  setUpAll(() {
    registerFallbackValue(<String>[]);
  });
}
