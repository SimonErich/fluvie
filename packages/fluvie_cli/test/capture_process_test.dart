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

  group('isFluvieProject', () {
    test('a pubspec whose dependencies include fluvie is a project', () {
      final dir = tempDir('fluvie_cli_is_project_');
      writeFluviePubspec(dir.path);

      expect(isFluvieProject(dir.path), isTrue);
    });

    test('a directory without a pubspec is not a project', () {
      expect(isFluvieProject(tempDir('fluvie_cli_no_pubspec_').path), isFalse);
    });

    test('a pubspec that does not depend on fluvie is not a project', () {
      final dir = tempDir('fluvie_cli_no_dep_');
      writePubspec(dir.path, '''
name: some_app
dependencies:
  flutter:
    sdk: flutter
  http: ^1.2.0
''');

      expect(isFluvieProject(dir.path), isFalse);
    });

    test('the fluvie package itself is not a project (its name: sits at column 0)', () {
      // The indent is what tells a `fluvie` dependency apart from the package
      // that IS fluvie; without it the walk would stop at packages/fluvie.
      final dir = tempDir('fluvie_cli_is_fluvie_');
      writePubspec(dir.path, '''
name: fluvie
description: The library itself.
dependencies:
  flutter:
    sdk: flutter
''');

      expect(isFluvieProject(dir.path), isFalse);
    });

    test('an indented fluvie: outside a dependency section is not a dependency', () {
      // fluvie_cli's own pubspec declares `executables:\n  fluvie:`, which is an
      // indented `fluvie:` that is not a dependency. Matching it would resolve
      // every render run from packages/fluvie_cli to the CLI package itself, a
      // pure-Dart package `flutter test` cannot run in.
      final dir = tempDir('fluvie_cli_executables_');
      writePubspec(dir.path, '''
name: fluvie_cli
executables:
  fluvie:
dependencies:
  args: ^2.7.0
''');

      expect(isFluvieProject(dir.path), isFalse);
    });

    test('a fluvie dev_dependency or dependency_override counts', () {
      final dev = tempDir('fluvie_cli_dev_dep_');
      writePubspec(dev.path, '''
name: some_app
dev_dependencies:
  fluvie: ^0.2.0
''');
      final override = tempDir('fluvie_cli_override_dep_');
      writePubspec(override.path, '''
name: some_app
dependency_overrides:
  fluvie:
    path: ../fluvie
''');

      expect(isFluvieProject(dev.path), isTrue);
      expect(isFluvieProject(override.path), isTrue);
    });
  });

  group('resolveProjectDir', () {
    test('an explicit --project is used verbatim', () {
      expect(resolveProjectDir(project: '/somewhere/app'), '/somewhere/app');
    });

    test('auto-discovers the example project walking up from cwd', () {
      final root = tempDir('fluvie_cli_project_');
      writeFluviePubspec('${root.path}/example');
      final nested = Directory('${root.path}/packages/fluvie_cli')..createSync(recursive: true);

      expect(resolveProjectDir(cwd: nested), '${root.absolute.path}/example');
      expect(resolveProjectDir(cwd: root), '${root.absolute.path}/example');
    });

    test('auto-discovers the monorepo gallery under examples/gallery', () {
      final root = tempDir('fluvie_cli_gallery_');
      writeFluviePubspec('${root.path}/examples/gallery');
      final nested = Directory('${root.path}/packages/fluvie_cli')..createSync(recursive: true);

      expect(resolveProjectDir(cwd: nested), '${root.absolute.path}/examples/gallery');
      expect(resolveProjectDir(cwd: root), '${root.absolute.path}/examples/gallery');
    });

    test('resolves a project whose own pubspec depends on fluvie', () {
      final root = tempDir('fluvie_cli_standalone_');
      writeFluviePubspec(root.path);
      final lib = Directory('${root.path}/lib/videos')..createSync(recursive: true);

      expect(resolveProjectDir(cwd: root), root.absolute.path);
      expect(resolveProjectDir(cwd: lib), root.absolute.path);
    });

    test('prefers the project itself over an "example" subproject in the same dir', () {
      final root = tempDir('fluvie_cli_both_');
      writeFluviePubspec(root.path);
      writeFluviePubspec('${root.path}/example');

      expect(resolveProjectDir(cwd: root), root.absolute.path);
    });

    test('a pubspec without a fluvie dependency does not stop the walk', () {
      // A plain package between the composition and the project (the shape of
      // the fluvie monorepo, whose packages/ sit above examples/gallery) must be
      // walked through, not resolved to.
      final root = tempDir('fluvie_cli_walk_through_');
      writeFluviePubspec('${root.path}/examples/gallery');
      final plain = Directory('${root.path}/packages/some_pkg')..createSync(recursive: true);
      writePubspec(plain.path, 'name: some_pkg\ndependencies:\n  args: ^2.7.0\n');

      expect(resolveProjectDir(cwd: plain), '${root.absolute.path}/examples/gallery');
    });

    test('fails with a --project hint when no Fluvie project is found', () {
      final empty = tempDir('fluvie_cli_no_project_');

      expect(
        () => resolveProjectDir(cwd: empty),
        throwsA(
          isA<CliFailure>()
              .having((e) => e.message, 'message', contains('--project'))
              .having((e) => e.message, 'message', contains('pubspec.yaml depending on fluvie'))
              .having((e) => e.message, 'message', contains('fluvie init')),
        ),
      );
    });
  });

  group('excerpt', () {
    test('output that fits in the two 4 KiB ends passes through unchanged', () {
      const short = 'a compile error\nand a verdict';
      expect(excerpt(short), short);
    });

    test('output exactly at the 8 KiB budget is not elided', () {
      final exact = 'x' * 8192;
      expect(excerpt(exact), exact);
    });

    test('a long output keeps the head, where the Dart compile error is printed', () {
      // The bug this fixes: a tail-only excerpt discarded the compile error in
      // the user's composition and left the reader a stack trace for an
      // exception they could not see.
      final output = 'COMPILE ERROR: line 3\n${'stack frame\n' * 2000}';
      final kept = excerpt(output);

      expect(kept, startsWith('COMPILE ERROR: line 3'));
      expect(kept, contains('characters elided'));
    });

    test('a long output keeps the tail, where the test runner verdict is printed', () {
      final output = '${'stack frame\n' * 2000}VERDICT: Some tests failed.';
      final kept = excerpt(output);

      expect(kept, endsWith('VERDICT: Some tests failed.'));
    });

    test('keeps both ends and names how many characters it dropped', () {
      final output = '${'H' * 5000}${'T' * 5000}';
      final kept = excerpt(output);

      expect(kept, startsWith('H' * 4096));
      expect(kept, endsWith('T' * 4096));
      expect(kept, contains('... [1808 characters elided] ...'));
      // 4096 head + 4096 tail + the marker line, never the whole 10000.
      expect(kept.length, lessThan(output.length));
    });
  });

  setUpAll(() {
    registerFallbackValue(<String>[]);
  });
}

/// A real temp directory, removed when the test ends.
Directory tempDir(String prefix) {
  final dir = Directory.systemTemp.createTempSync(prefix);
  addTearDown(() {
    if (dir.existsSync()) dir.deleteSync(recursive: true);
  });
  return dir;
}

/// Writes [body] as [dir]'s pubspec, creating [dir].
void writePubspec(String dir, String body) => File('$dir/pubspec.yaml')
  ..createSync(recursive: true)
  ..writeAsStringSync(body);

/// Writes the pubspec of a Fluvie project: a `fluvie:` entry indented under
/// `dependencies:`, which is what [isFluvieProject] probes for.
void writeFluviePubspec(String dir, {String name = 'demo_video'}) => writePubspec(dir, '''
name: $name
environment:
  sdk: ^3.12.0
dependencies:
  flutter:
    sdk: flutter
  fluvie: ^0.2.0
''');
