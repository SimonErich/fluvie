import 'dart:io';

import 'package:fluvie_cli/src/capture_process.dart';
import 'package:fluvie_cli/src/cli_failure.dart';
import 'package:fluvie_cli/src/process_runner.dart';
import 'package:mocktail/mocktail.dart';
import 'package:test/test.dart';

class _MockProcessRunner extends Mock implements ProcessRunner {}

void main() {
  final sandbox = Directory('/tmp/fluvie_render_test_sandbox');
  late _MockProcessRunner runner;

  setUp(() {
    runner = _MockProcessRunner();
  });

  void stubFlutterTest({int exitCode = 0, String stdout = '', String stderr = ''}) {
    when(
      () => runner.run('flutter', any(), workingDirectory: any(named: 'workingDirectory')),
    ).thenAnswer((_) async => ProcessRunResult(exitCode: exitCode, stdout: stdout, stderr: stderr));
  }

  group('captureTestArgs', () {
    test('builds the exact harness argv with the two mandatory defines', () {
      expect(captureTestArgs(key: 'demo', sandbox: sandbox), [
        'test',
        '--no-pub',
        'test/render/capture_harness_test.dart',
        '--dart-define=FLUVIE_RENDER_KEY=demo',
        '--dart-define=FLUVIE_RENDER_OUT_DIR=${sandbox.path}',
      ]);
    });

    test('adds the frames and no-cache defines when requested', () {
      expect(
        captureTestArgs(key: 'demo', sandbox: sandbox, frames: 8, noCache: true),
        containsAllInOrder(<String>[
          '--dart-define=FLUVIE_RENDER_FRAMES=8',
          '--dart-define=FLUVIE_RENDER_NO_CACHE=true',
        ]),
      );
    });

    test('adds the aspect/quality/format/poster defines when requested', () {
      final args = captureTestArgs(
        key: 'demo',
        sandbox: sandbox,
        aspect: 'square',
        quality: 'max',
        format: 'gif',
        poster: '1.5s',
      );
      expect(
        args,
        containsAllInOrder(<String>[
          '--dart-define=FLUVIE_RENDER_ASPECT=square',
          '--dart-define=FLUVIE_RENDER_QUALITY=max',
          '--dart-define=FLUVIE_RENDER_FORMAT=gif',
          '--dart-define=FLUVIE_RENDER_POSTER=1.5s',
        ]),
      );
    });

    test('omits the new defines when they are not given (plain render unchanged)', () {
      final args = captureTestArgs(key: 'demo', sandbox: sandbox);
      expect(args, isNot(contains(contains('FLUVIE_RENDER_ASPECT'))));
      expect(args, isNot(contains(contains('FLUVIE_RENDER_QUALITY'))));
      expect(args, isNot(contains(contains('FLUVIE_RENDER_FORMAT'))));
      expect(args, isNot(contains(contains('FLUVIE_RENDER_POSTER'))));
    });

    test('adds --enable-impeller (before the harness file) when impeller is set', () {
      final args = captureTestArgs(key: 'demo', sandbox: sandbox, impeller: true);
      expect(
        args,
        containsAllInOrder(<String>['--enable-impeller', 'test/render/capture_harness_test.dart']),
      );
    });

    test('omits --enable-impeller by default (plain render unchanged)', () {
      expect(captureTestArgs(key: 'demo', sandbox: sandbox), isNot(contains('--enable-impeller')));
    });

    test('a custom harnessPath replaces the default harness test in the argv', () {
      final args = captureTestArgs(
        key: '',
        sandbox: sandbox,
        harnessPath: '.fluvie_playground/abc/harness_test.dart',
      );
      expect(args, contains('.fluvie_playground/abc/harness_test.dart'));
      expect(args, isNot(contains('test/render/capture_harness_test.dart')));
    });

    test('the default harnessPath keeps the permanent harness (byte-identical)', () {
      expect(
        captureTestArgs(key: 'demo', sandbox: sandbox),
        contains(
          'test/render/capture_harness_test.dart',
        ),
      );
    });
  });

  group('runCapture', () {
    test('spawns flutter test in the project directory with the exact argv', () async {
      stubFlutterTest();

      await runCapture(
        runner: runner,
        projectDir: 'example',
        key: 'demo',
        sandbox: sandbox,
        err: StringBuffer(),
      );

      verify(
        () => runner.run('flutter', [
          'test',
          '--no-pub',
          'test/render/capture_harness_test.dart',
          '--dart-define=FLUVIE_RENDER_KEY=demo',
          '--dart-define=FLUVIE_RENDER_OUT_DIR=${sandbox.path}',
        ], workingDirectory: 'example'),
      ).called(1);
    });

    test('a custom harnessPath is spawned in place of the permanent harness', () async {
      stubFlutterTest();

      await runCapture(
        runner: runner,
        projectDir: 'example',
        key: '',
        sandbox: sandbox,
        harnessPath: '.fluvie_playground/abc/harness_test.dart',
        err: StringBuffer(),
      );

      final captured =
          verify(
                () => runner.run('flutter', captureAny(), workingDirectory: 'example'),
              ).captured.single
              as List<String>;
      expect(captured, contains('.fluvie_playground/abc/harness_test.dart'));
      expect(captured, isNot(contains('test/render/capture_harness_test.dart')));
    });

    test('impeller adds --enable-impeller to the spawned argv', () async {
      stubFlutterTest();

      await runCapture(
        runner: runner,
        projectDir: 'example',
        key: 'demo',
        sandbox: sandbox,
        impeller: true,
        err: StringBuffer(),
      );

      final captured =
          verify(
                () => runner.run('flutter', captureAny(), workingDirectory: 'example'),
              ).captured.single
              as List<String>;
      expect(captured, contains('--enable-impeller'));
    });

    test('a non-zero exit throws a CliFailure carrying the test output', () async {
      stubFlutterTest(exitCode: 1, stdout: 'some unrelated flutter-test failure tail');

      await expectLater(
        () => runCapture(
          runner: runner,
          projectDir: 'example',
          key: 'nope',
          sandbox: sandbox,
          err: StringBuffer(),
        ),
        throwsA(
          isA<CliFailure>()
              .having((e) => e.message, 'message', contains('exit code 1'))
              .having((e) => e.message, 'message', contains('flutter-test failure tail')),
        ),
      );
    });

    test('an unknown-key marker surfaces a friendly message, not the raw tail', () async {
      stubFlutterTest(
        exitCode: 1,
        stdout:
            'noise above\n'
            '$runCaptureUnknownKeyMarker Unknown composition key "nope". '
            'Known keys: [demo, multi_scene]\n'
            'a long flutter-test stack trace tail that should be hidden',
      );

      await expectLater(
        () => runCapture(
          runner: runner,
          projectDir: 'example',
          key: 'nope',
          sandbox: sandbox,
          err: StringBuffer(),
        ),
        throwsA(
          isA<CliFailure>()
              .having((e) => e.message, 'message', contains('Unknown composition key "nope"'))
              .having((e) => e.message, 'message', contains('fluvie list'))
              .having((e) => e.message, 'message', isNot(contains('stack trace tail'))),
        ),
      );
    });

    test('a missing flutter binary (ProcessException) fails with an install hint', () async {
      when(
        () => runner.run('flutter', any(), workingDirectory: any(named: 'workingDirectory')),
      ).thenThrow(const ProcessException('flutter', ['test'], 'No such file or directory'));

      await expectLater(
        () => runCapture(
          runner: runner,
          projectDir: 'example',
          key: 'demo',
          sandbox: sandbox,
          err: StringBuffer(),
        ),
        throwsA(
          isA<CliFailure>()
              .having((e) => e.message, 'message', contains('flutter'))
              .having((e) => e.message, 'message', contains('PATH')),
        ),
      );
    });

    test('verbose forwards the flutter test output to err', () async {
      stubFlutterTest(stdout: 'fluvie-capture: cache hits 48 of 48', stderr: 'warning: x');
      final err = StringBuffer();

      await runCapture(
        runner: runner,
        projectDir: 'example',
        key: 'demo',
        sandbox: sandbox,
        err: err,
        verbose: true,
      );

      expect(err.toString(), contains('cache hits 48 of 48'));
      expect(err.toString(), contains('warning: x'));
    });

    test('without verbose nothing is forwarded on success', () async {
      stubFlutterTest(stdout: 'noise');
      final err = StringBuffer();

      await runCapture(
        runner: runner,
        projectDir: 'example',
        key: 'demo',
        sandbox: sandbox,
        err: err,
      );

      expect(err.toString(), isEmpty);
    });

    test('forwards a given environment to the flutter-test run', () async {
      when(
        () => runner.run(
          'flutter',
          any(),
          workingDirectory: any(named: 'workingDirectory'),
          environment: any(named: 'environment'),
        ),
      ).thenAnswer((_) async => const ProcessRunResult(exitCode: 0, stdout: '', stderr: ''));

      await runCapture(
        runner: runner,
        projectDir: 'example',
        key: 'demo',
        sandbox: sandbox,
        err: StringBuffer(),
        environment: const {'FLUVIE_PROGRESS_FILE': '/tmp/p'},
      );

      final captured = verify(
        () => runner.run(
          'flutter',
          any(),
          workingDirectory: any(named: 'workingDirectory'),
          environment: captureAny(named: 'environment'),
        ),
      ).captured.single;
      expect(captured, {'FLUVIE_PROGRESS_FILE': '/tmp/p'});
    });
  });

  group('resolveProjectDir', () {
    test('an explicit --project is used verbatim', () {
      expect(resolveProjectDir(project: '/somewhere/app'), '/somewhere/app');
    });

    test('auto-discovers the example project walking up from cwd', () {
      final root = Directory.systemTemp.createTempSync('fluvie_cli_project_');
      addTearDown(() => root.deleteSync(recursive: true));
      File(
        '${root.path}/example/test/render/capture_harness_test.dart',
      ).createSync(recursive: true);
      final nested = Directory('${root.path}/packages/fluvie_cli')..createSync(recursive: true);

      expect(resolveProjectDir(cwd: nested), '${root.absolute.path}/example');
      expect(resolveProjectDir(cwd: root), '${root.absolute.path}/example');
    });

    test('auto-discovers the monorepo gallery under examples/gallery', () {
      final root = Directory.systemTemp.createTempSync('fluvie_cli_gallery_');
      addTearDown(() => root.deleteSync(recursive: true));
      File(
        '${root.path}/examples/gallery/test/render/capture_harness_test.dart',
      ).createSync(recursive: true);
      final nested = Directory('${root.path}/packages/fluvie_cli')..createSync(recursive: true);

      expect(resolveProjectDir(cwd: nested), '${root.absolute.path}/examples/gallery');
      expect(resolveProjectDir(cwd: root), '${root.absolute.path}/examples/gallery');
    });

    test('resolves a standalone project whose harness sits directly in it', () {
      final root = Directory.systemTemp.createTempSync('fluvie_cli_standalone_');
      addTearDown(() => root.deleteSync(recursive: true));
      File(
        '${root.path}/test/render/capture_harness_test.dart',
      ).createSync(recursive: true);
      final lib = Directory('${root.path}/lib/videos')..createSync(recursive: true);

      expect(resolveProjectDir(cwd: root), root.absolute.path);
      expect(resolveProjectDir(cwd: lib), root.absolute.path);
    });

    test('prefers a standalone harness over an "example" subproject in the same dir', () {
      final root = Directory.systemTemp.createTempSync('fluvie_cli_both_');
      addTearDown(() => root.deleteSync(recursive: true));
      File('${root.path}/test/render/capture_harness_test.dart').createSync(recursive: true);
      File(
        '${root.path}/example/test/render/capture_harness_test.dart',
      ).createSync(recursive: true);

      expect(resolveProjectDir(cwd: root), root.absolute.path);
    });

    test('fails with a --project hint when no harness is found', () {
      final empty = Directory.systemTemp.createTempSync('fluvie_cli_no_project_');
      addTearDown(() => empty.deleteSync(recursive: true));

      expect(
        () => resolveProjectDir(cwd: empty),
        throwsA(isA<CliFailure>().having((e) => e.message, 'message', contains('--project'))),
      );
    });
  });

  setUpAll(() {
    registerFallbackValue(<String>[]);
  });
}
