import 'dart:collection';
import 'dart:io';

import 'package:fluvie_cli/src/init_command.dart';
import 'package:fluvie_cli/src/init_prompt.dart';
import 'package:fluvie_cli/src/init_support.dart' show fluvieDependencyVersion;
import 'package:fluvie_cli/src/process_runner.dart';
import 'package:mocktail/mocktail.dart';
import 'package:test/test.dart';

class _MockProcessRunner extends Mock implements ProcessRunner {}

void main() {
  setUpAll(() {
    registerFallbackValue(<String>[]);
    registerFallbackValue('');
  });

  Directory flutterProject({bool withFluvie = false}) {
    final dir = Directory.systemTemp.createTempSync('fluvie_init_');
    addTearDown(() => dir.deleteSync(recursive: true));
    File('${dir.path}/pubspec.yaml').writeAsStringSync('''
name: my_app
environment:
  sdk: ^3.12.0
dependencies:
  flutter:
    sdk: flutter
${withFluvie ? '  fluvie: ^0.1.0\n' : ''}dev_dependencies:
  flutter_test:
    sdk: flutter
''');
    return dir;
  }

  Directory emptyDir() {
    final dir = Directory.systemTemp.createTempSync('fluvie_init_empty_');
    addTearDown(() => dir.deleteSync(recursive: true));
    return dir;
  }

  LineReader answers(List<String> lines) {
    final queue = Queue<String>.of(lines);
    return () => queue.isEmpty ? null : queue.removeFirst();
  }

  Future<({int code, String out, String err})> runInit(
    List<String> args, {
    required Directory cwd,
    ProcessRunner? runner,
    LineReader? readLine,
  }) async {
    final out = StringBuffer();
    final err = StringBuffer();
    final code = await InitCommand(
      runner: runner ?? const IoProcessRunner(),
      readLine: readLine,
      workingDirectory: cwd,
    ).execute(InitCommand.buildParser().parse(args), out: out, err: err);
    return (code: code, out: out.toString(), err: err.toString());
  }

  test('constructs with defaults (no injection)', () {
    expect(InitCommand(), isNotNull);
    expect(InitCommand.buildParser().options, contains('name'));
  });

  group('existing Flutter project', () {
    test('--yes writes the composition, adds the dep, and scaffolds the harness', () async {
      final dir = flutterProject();
      final result = await runInit(['--yes'], cwd: dir);

      expect(result.code, 0);
      expect(File('${dir.path}/lib/videos/starter.dart').existsSync(), isTrue);
      final harness = File('${dir.path}/test/render/capture_harness_test.dart');
      expect(harness.existsSync(), isTrue);
      expect(harness.readAsStringSync(), contains('package:my_app/videos/starter.dart'));
      expect(harness.readAsStringSync(), contains("'starter': starterVideo,"));
      expect(File('${dir.path}/test/starter_test.dart').existsSync(), isTrue);

      final pubspec = File('${dir.path}/pubspec.yaml').readAsStringSync();
      expect(pubspec, contains('fluvie: $fluvieDependencyVersion'));
      expect(pubspec, contains('alchemist:'));
    });

    test('does not re-add fluvie when it is already a dependency', () async {
      final dir = flutterProject(withFluvie: true);
      final result = await runInit(['--yes'], cwd: dir);

      expect(result.code, 0);
      expect(
        'fluvie:'.allMatches(File('${dir.path}/pubspec.yaml').readAsStringSync()).length,
        1,
      );
    });

    test('--path writes the composition at the chosen location', () async {
      final dir = flutterProject();
      final result = await runInit(['--yes', '--path', 'lib/clips/hero.dart'], cwd: dir);

      expect(result.code, 0);
      expect(File('${dir.path}/lib/clips/hero.dart').existsSync(), isTrue);
    });

    test('--name drives the key, file, and function names', () async {
      final dir = flutterProject();
      await runInit(['--yes', '--name', 'Intro Clip'], cwd: dir);

      expect(File('${dir.path}/lib/videos/intro_clip.dart').existsSync(), isTrue);
      expect(
        File('${dir.path}/lib/videos/intro_clip.dart').readAsStringSync(),
        contains('Video introClipVideo()'),
      );
      expect(
        File('${dir.path}/test/render/capture_harness_test.dart').readAsStringSync(),
        contains("'intro_clip': introClipVideo,"),
      );
    });

    test('refuses to overwrite without --force, then overwrites with it', () async {
      final dir = flutterProject();
      File('${dir.path}/lib/videos/starter.dart')
        ..createSync(recursive: true)
        ..writeAsStringSync('// mine');

      final blocked = await runInit(['--yes'], cwd: dir);
      expect(blocked.code, 1);
      expect(blocked.err, contains('--force'));
      expect(File('${dir.path}/lib/videos/starter.dart').readAsStringSync(), '// mine');

      final forced = await runInit(['--yes', '--force'], cwd: dir);
      expect(forced.code, 0);
      expect(File('${dir.path}/lib/videos/starter.dart').readAsStringSync(), contains('Video'));
    });

    test('skips the harness when the composition is not under lib/', () async {
      final dir = flutterProject();
      final result = await runInit(['--yes', '--path', 'starter.dart'], cwd: dir);

      expect(result.code, 0);
      expect(File('${dir.path}/starter.dart').existsSync(), isTrue);
      expect(result.err, contains('under lib/'));
      expect(File('${dir.path}/test/render/capture_harness_test.dart').existsSync(), isFalse);
    });

    test('skips the harness when pubspec has no package name', () async {
      final dir = Directory.systemTemp.createTempSync('fluvie_init_noname_');
      addTearDown(() => dir.deleteSync(recursive: true));
      File('${dir.path}/pubspec.yaml').writeAsStringSync('''
dependencies:
  flutter:
    sdk: flutter
''');

      final result = await runInit(['--yes'], cwd: dir);

      expect(result.code, 0);
      expect(result.err, contains('no package name'));
      expect(File('${dir.path}/test/render/capture_harness_test.dart').existsSync(), isFalse);
    });

    test('--no-render skips the harness and test', () async {
      final dir = flutterProject();
      final result = await runInit(['--yes', '--no-render'], cwd: dir);

      expect(result.code, 0);
      expect(File('${dir.path}/lib/videos/starter.dart').existsSync(), isTrue);
      expect(File('${dir.path}/test/render/capture_harness_test.dart').existsSync(), isFalse);
    });

    test('interactive: prompts for the path and the render question', () async {
      final dir = flutterProject();
      final result = await runInit(
        const [],
        cwd: dir,
        readLine: answers(['lib/clips/hero.dart', 'n']),
      );

      expect(result.code, 0);
      expect(result.out, contains('Where should the composition go?'));
      expect(File('${dir.path}/lib/clips/hero.dart').existsSync(), isTrue);
      expect(File('${dir.path}/test/render/capture_harness_test.dart').existsSync(), isFalse);
    });

    test('interactive: pressing Enter accepts the default path and harness', () async {
      final dir = flutterProject();
      final result = await runInit(const [], cwd: dir, readLine: answers(['', '']));

      expect(result.code, 0);
      expect(File('${dir.path}/lib/videos/starter.dart').existsSync(), isTrue);
      expect(File('${dir.path}/test/render/capture_harness_test.dart').existsSync(), isTrue);
    });
  });

  group('new project (not a Flutter project)', () {
    late _MockProcessRunner runner;

    setUp(() => runner = _MockProcessRunner());

    void stubFlutterCreate({int exitCode = 0}) {
      when(
        () => runner.run('flutter', any(), workingDirectory: any(named: 'workingDirectory')),
      ).thenAnswer((invocation) async {
        if (exitCode != 0) {
          return ProcessRunResult(exitCode: exitCode, stdout: '', stderr: 'boom');
        }
        final args = invocation.positionalArguments[1] as List<String>;
        final dirName = args.last;
        final pkg = args[args.indexOf('--project-name') + 1];
        final wd = invocation.namedArguments[#workingDirectory] as String;
        final proj =
            (Directory(dirName).isAbsolute ? Directory(dirName) : Directory('$wd/$dirName'))
              ..createSync(recursive: true);
        File('${proj.path}/pubspec.yaml').writeAsStringSync('''
name: $pkg
dependencies:
  flutter:
    sdk: flutter
dev_dependencies:
  flutter_test:
    sdk: flutter
''');
        File('${proj.path}/lib/main.dart')
          ..createSync(recursive: true)
          ..writeAsStringSync('// counter app');
        File('${proj.path}/test/widget_test.dart')
          ..createSync(recursive: true)
          ..writeAsStringSync('// counter test');
        return const ProcessRunResult(exitCode: 0, stdout: '', stderr: '');
      });
    }

    test('--yes runs flutter create and overlays the Fluvie files', () async {
      final cwd = emptyDir();
      stubFlutterCreate();

      final result = await runInit(['--yes', '--dir', 'demo_video'], cwd: cwd, runner: runner);

      expect(result.code, 0);
      final proj = '${cwd.path}/demo_video';
      expect(File('$proj/lib/videos/starter.dart').existsSync(), isTrue);
      expect(File('$proj/lib/main.dart').readAsStringSync(), contains('FluviePreviewApp'));
      expect(File('$proj/test/widget_test.dart').existsSync(), isFalse);
      expect(File('$proj/test/starter_test.dart').existsSync(), isTrue);
      expect(File('$proj/test/render/capture_harness_test.dart').existsSync(), isTrue);

      final pubspec = File('$proj/pubspec.yaml').readAsStringSync();
      expect(pubspec, contains('fluvie: $fluvieDependencyVersion'));
      expect(pubspec, contains('alchemist:'));

      verify(
        () => runner.run(
          'flutter',
          any(that: containsAllInOrder(['create', '--project-name', 'demo_video', 'demo_video'])),
          workingDirectory: cwd.path,
        ),
      ).called(1);
    });

    test('interactive: confirms then prompts for the project directory', () async {
      final cwd = emptyDir();
      stubFlutterCreate();

      final result = await runInit(
        const [],
        cwd: cwd,
        runner: runner,
        readLine: answers(['y', 'cool_demo']),
      );

      expect(result.code, 0);
      expect(result.out, contains('Project directory'));
      expect(File('${cwd.path}/cool_demo/lib/videos/starter.dart').existsSync(), isTrue);
    });

    test('accepts an absolute --dir', () async {
      final cwd = emptyDir();
      final target = Directory('${cwd.path}/nested/abs_project');
      stubFlutterCreate();

      final result = await runInit(['--yes', '--dir', target.path], cwd: cwd, runner: runner);

      expect(result.code, 0);
      expect(File('${target.path}/lib/videos/starter.dart').existsSync(), isTrue);
    });

    test('interactive decline creates nothing', () async {
      final cwd = emptyDir();

      final result = await runInit(const [], cwd: cwd, runner: runner, readLine: answers(['n']));

      expect(result.code, 0);
      expect(result.out, contains('Nothing created'));
      verifyNever(
        () => runner.run(any(), any(), workingDirectory: any(named: 'workingDirectory')),
      );
    });

    test('a failed flutter create surfaces as exit 1', () async {
      final cwd = emptyDir();
      stubFlutterCreate(exitCode: 1);

      final result = await runInit(['--yes'], cwd: cwd, runner: runner);

      expect(result.code, 1);
      expect(result.err, contains('flutter create failed'));
    });

    test('a missing flutter binary fails with an install hint', () async {
      final cwd = emptyDir();
      when(
        () => runner.run('flutter', any(), workingDirectory: any(named: 'workingDirectory')),
      ).thenThrow(const ProcessException('flutter', ['create']));

      final result = await runInit(['--yes'], cwd: cwd, runner: runner);

      expect(result.code, 1);
      expect(result.err, contains('PATH'));
    });
  });
}
