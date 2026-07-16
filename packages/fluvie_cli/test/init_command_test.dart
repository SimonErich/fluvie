import 'dart:io';

import 'package:fluvie_cli/src/init_command.dart';
import 'package:fluvie_cli/src/init_support.dart' show fluvieDependencyVersion;
import 'package:path/path.dart' as p;
import 'package:test/test.dart';

void main() {
  late Directory cwd;

  setUp(() {
    cwd = Directory.systemTemp.createTempSync('fluvie_init_');
    addTearDown(() {
      if (cwd.existsSync()) cwd.deleteSync(recursive: true);
    });
  });

  Future<({int code, String out, String err})> runInit(List<String> args) async {
    final out = StringBuffer();
    final err = StringBuffer();
    final code = await InitCommand(
      workingDirectory: cwd,
    ).execute(InitCommand.buildParser().parse(args), out: out, err: err);
    return (code: code, out: out.toString(), err: err.toString());
  }

  test('constructs with defaults (no injection)', () {
    expect(InitCommand(), isNotNull);
  });

  group('buildParser', () {
    test('takes --name, --dir and --force', () {
      final options = InitCommand.buildParser().options;

      expect(options, contains('name'));
      expect(options, contains('dir'));
      expect(options, contains('force'));
    });

    test('is no longer interactive and no longer scaffolds a render harness', () {
      // `fluvie init` writes a composition, a pubspec and assets/. It runs no
      // `flutter create`, asks no questions, and the harness a render needs is
      // generated per render instead of committed.
      final options = InitCommand.buildParser().options;

      expect(options, isNot(contains('yes')));
      expect(options, isNot(contains('path')));
      expect(options, isNot(contains('no-render')));
    });
  });

  group('scaffolding', () {
    test('writes the project into the working directory and says where', () async {
      final result = await runInit(const []);

      expect(result.code, 0, reason: result.err);
      expect(File(p.join(cwd.path, 'lib', 'example_video.dart')).existsSync(), isTrue);
      expect(File(p.join(cwd.path, 'pubspec.yaml')).existsSync(), isTrue);
      expect(File(p.join(cwd.path, 'assets', '.gitkeep')).existsSync(), isTrue);
      expect(result.out, contains('Scaffolding a Fluvie project in ${cwd.path}'));
    });

    test('the scaffolded pubspec depends on fluvie', () async {
      await runInit(const []);

      expect(
        File(p.join(cwd.path, 'pubspec.yaml')).readAsStringSync(),
        contains('fluvie: $fluvieDependencyVersion'),
      );
    });

    test('scaffolds nothing a render or preview generates for itself', () async {
      await runInit(const []);

      expect(File(p.join(cwd.path, 'lib', 'main.dart')).existsSync(), isFalse);
      expect(
        File(p.join(cwd.path, 'test', 'render', 'capture_harness_test.dart')).existsSync(),
        isFalse,
      );
      expect(Directory(p.join(cwd.path, 'android')).existsSync(), isFalse);
    });

    test('--name drives the composition file name', () async {
      final result = await runInit(const ['--name', 'Intro Clip']);

      expect(result.code, 0, reason: result.err);
      expect(File(p.join(cwd.path, 'lib', 'intro_clip.dart')).existsSync(), isTrue);
    });

    test('--dir scaffolds into a subdirectory, creating it', () async {
      final result = await runInit(const ['--dir', 'demo_video']);

      expect(result.code, 0, reason: result.err);
      final project = p.join(cwd.path, 'demo_video');
      expect(File(p.join(project, 'lib', 'example_video.dart')).existsSync(), isTrue);
      expect(
        File(p.join(project, 'pubspec.yaml')).readAsStringSync(),
        contains('name: demo_video'),
      );
    });

    test('--dir accepts an absolute path', () async {
      final target = p.join(cwd.path, 'nested', 'abs_project');

      final result = await runInit(['--dir', target]);

      expect(result.code, 0, reason: result.err);
      expect(File(p.join(target, 'lib', 'example_video.dart')).existsSync(), isTrue);
    });

    test('a composition drops into an existing Flutter project', () async {
      File(p.join(cwd.path, 'pubspec.yaml')).writeAsStringSync('''
name: my_app
dependencies:
  flutter:
    sdk: flutter
''');

      final result = await runInit(const []);

      expect(result.code, 0, reason: result.err);
      expect(File(p.join(cwd.path, 'lib', 'example_video.dart')).existsSync(), isTrue);
      expect(result.out, contains('skipped pubspec.yaml (already exists)'));
    });
  });

  group('failures', () {
    test('refuses a directory holding a non-Flutter pubspec', () async {
      File(p.join(cwd.path, 'pubspec.yaml')).writeAsStringSync('''
name: cli_tool
dependencies:
  args: ^2.7.0
''');

      final result = await runInit(const []);

      expect(result.code, 1);
      expect(result.err, contains('not a Flutter'));
      expect(File(p.join(cwd.path, 'lib', 'example_video.dart')).existsSync(), isFalse);
    });

    test('--force scaffolds into a non-Flutter package anyway', () async {
      File(p.join(cwd.path, 'pubspec.yaml')).writeAsStringSync('''
name: cli_tool
dependencies:
  args: ^2.7.0
''');

      final result = await runInit(const ['--force']);

      expect(result.code, 0, reason: result.err);
      expect(File(p.join(cwd.path, 'lib', 'example_video.dart')).existsSync(), isTrue);
    });

    test('a re-run without --force changes nothing and asks for --force', () async {
      await runInit(const []);

      final second = await runInit(const []);

      expect(second.code, 1);
      expect(second.err, contains('--force'));
    });

    test('--force overwrites an edited composition', () async {
      await runInit(const []);
      File(p.join(cwd.path, 'lib', 'example_video.dart')).writeAsStringSync('// mine');

      final forced = await runInit(const ['--force']);

      expect(forced.code, 0, reason: forced.err);
      expect(
        File(p.join(cwd.path, 'lib', 'example_video.dart')).readAsStringSync(),
        contains('Video build()'),
      );
    });
  });
}
