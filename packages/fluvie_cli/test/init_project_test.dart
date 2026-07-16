import 'dart:io';

import 'package:fluvie_cli/src/cli_failure.dart';
import 'package:fluvie_cli/src/init_project.dart';
import 'package:fluvie_cli/src/init_support.dart' show fluvieDependencyVersion;
import 'package:path/path.dart' as p;
import 'package:test/test.dart';

void main() {
  late Directory dir;
  late StringBuffer out;
  late StringBuffer err;

  setUp(() {
    dir = Directory.systemTemp.createTempSync('fluvie_init_project_');
    out = StringBuffer();
    err = StringBuffer();
    addTearDown(() {
      if (dir.existsSync()) dir.deleteSync(recursive: true);
    });
  });

  Future<int> scaffold({String fileName = 'example_video.dart', bool force = false}) =>
      initProject(dir: dir, fileName: fileName, force: force, out: out, err: err);

  /// Every file in [dir], as project-relative paths in sorted order.
  List<String> files() =>
      (dir
          .listSync(recursive: true)
          .whereType<File>()
          .map(
            (f) => p.relative(f.path, from: dir.path),
          )
          .toList()
        ..sort());

  String read(String relative) => File(p.join(dir.path, relative)).readAsStringSync();

  group('initProject', () {
    test('writes exactly the project: a pubspec, a composition, and assets', () async {
      // A Fluvie project is a composition file, an assets/ folder and a
      // pubspec. No app, no main.dart, no capture harness, no registry, and no
      // platform directories.
      expect(await scaffold(), 0, reason: err.toString());

      expect(files(), [
        '.gitignore',
        'analysis_options.yaml',
        'assets/.gitkeep',
        'lib/example_video.dart',
        'pubspec.yaml',
      ]);
    });

    test('the composition goes under lib/, so it has a package: URI', () async {
      // `fluvie preview` runs a generated app from OUTSIDE the project, and a
      // relative import cannot escape a package, so a composition anywhere else
      // could be rendered but never previewed.
      await scaffold();

      expect(File(p.join(dir.path, 'lib', 'example_video.dart')).existsSync(), isTrue);
      expect(File(p.join(dir.path, 'example_video.dart')).existsSync(), isFalse);
    });

    test('the pubspec names the package after the directory and pins fluvie', () async {
      await scaffold();

      final pubspec = read('pubspec.yaml');
      expect(pubspec, contains('name: ${packageNameFor(dir.path)}'));
      expect(pubspec, contains('fluvie: $fluvieDependencyVersion'));
      expect(pubspec, contains('alchemist:'));
    });

    test('the pubspec declares no assets block: the CLI derives it per render', () async {
      // A hand-written `assets/` would silently miss anything in a
      // subdirectory, because Flutter bundles a declared asset directory
      // non-recursively.
      await scaffold();

      expect(read('pubspec.yaml'), isNot(contains('assets:')));
    });

    test('the composition declares a top-level Video build()', () async {
      await scaffold();

      final composition = read(p.join('lib', 'example_video.dart'));
      expect(composition, contains('Video build()'));
      expect(composition, contains("import 'package:fluvie/fluvie.dart';"));
    });

    test('the .gitignore covers the CLI generated directories', () async {
      await scaffold();

      expect(read('.gitignore'), contains('.fluvie/'));
    });

    test('analysis_options.yaml wires the custom_lint plugin', () async {
      await scaffold();

      expect(read('analysis_options.yaml'), contains('custom_lint'));
    });

    test('a custom file name is used for the composition', () async {
      expect(await scaffold(fileName: 'intro_clip.dart'), 0);

      expect(File(p.join(dir.path, 'lib', 'intro_clip.dart')).existsSync(), isTrue);
      expect(File(p.join(dir.path, 'lib', 'example_video.dart')).existsSync(), isFalse);
    });

    test('the composition header names the file it was actually scaffolded as', () async {
      // The header is the first thing you read in a new project, so a copied
      // command out of it has to be the one that renders THIS file.
      await scaffold(fileName: 'intro_clip.dart');

      final composition = read(p.join('lib', 'intro_clip.dart'));
      expect(composition, contains('fluvie preview ./lib/intro_clip.dart'));
      expect(composition, contains('fluvie render ./lib/intro_clip.dart --out intro_clip.mp4'));
    });

    test('reports what it created and what to run next', () async {
      await scaffold();

      expect(out.toString(), contains('created pubspec.yaml'));
      expect(out.toString(), contains('created lib/example_video.dart'));
      expect(out.toString(), contains('flutter pub get'));
      expect(out.toString(), contains('fluvie preview ./lib/example_video.dart'));
      expect(
        out.toString(),
        contains('fluvie render ./lib/example_video.dart --out example_video.mp4'),
      );
    });

    test('a re-run without --force changes nothing and asks for --force', () async {
      await scaffold();
      final before = read(p.join('lib', 'example_video.dart'));

      final second = await initProject(
        dir: dir,
        fileName: 'example_video.dart',
        force: false,
        out: StringBuffer(),
        err: err = StringBuffer(),
      );

      expect(second, 1);
      expect(err.toString(), contains('--force'));
      expect(read(p.join('lib', 'example_video.dart')), before);
    });

    test('--force overwrites an edited composition', () async {
      await scaffold();
      File(p.join(dir.path, 'lib', 'example_video.dart')).writeAsStringSync('// mine');

      expect(await scaffold(force: true), 0);

      expect(read(p.join('lib', 'example_video.dart')), contains('Video build()'));
    });

    test('an existing file is skipped and reported, the rest is still written', () async {
      File(p.join(dir.path, 'lib', 'example_video.dart'))
        ..createSync(recursive: true)
        ..writeAsStringSync('// mine');

      expect(await scaffold(), 0, reason: err.toString());

      expect(read(p.join('lib', 'example_video.dart')), '// mine');
      expect(out.toString(), contains('skipped lib/example_video.dart (already exists)'));
      expect(File(p.join(dir.path, 'pubspec.yaml')).existsSync(), isTrue);
    });
  });

  group('packageNameFor', () {
    test('passes through a valid name', () {
      expect(packageNameFor('/tmp/my_fluvie_video'), 'my_fluvie_video');
    });

    test('folds punctuation and case into a legal name', () {
      expect(packageNameFor('/tmp/My-Cool.App'), 'my_cool_app');
    });

    test('prefixes a digit-leading name', () {
      // `import 'package:2_cats/...'` does not parse, so a package name must be
      // a valid Dart identifier.
      expect(packageNameFor('/tmp/123app'), 'app_123app');
      expect(packageNameFor('/tmp/2_cats'), 'app_2_cats');
    });

    test('uses the last path segment', () {
      expect(packageNameFor('/tmp/some/cool_clip'), 'cool_clip');
    });

    test('a name that folds away entirely falls back', () {
      expect(packageNameFor('/tmp/---'), 'fluvie_video');
    });
  });

  group('assertScaffoldable', () {
    test('an empty directory is scaffoldable', () {
      expect(() => assertScaffoldable(dir), returnsNormally);
    });

    test('a directory that does not exist yet is scaffoldable', () {
      expect(
        () => assertScaffoldable(Directory(p.join(dir.path, 'new_project'))),
        returnsNormally,
      );
    });

    test('an existing Flutter project is scaffoldable: the composition drops in', () {
      File(p.join(dir.path, 'pubspec.yaml')).writeAsStringSync('''
name: my_app
dependencies:
  flutter:
    sdk: flutter
''');

      expect(() => assertScaffoldable(dir), returnsNormally);
    });

    test('a non-Flutter package refuses, naming --force', () {
      File(p.join(dir.path, 'pubspec.yaml')).writeAsStringSync('''
name: cli_tool
dependencies:
  args: ^2.7.0
''');

      expect(
        () => assertScaffoldable(dir),
        throwsA(
          isA<CliFailure>()
              .having((e) => e.message, 'message', contains('not a Flutter'))
              .having((e) => e.message, 'message', contains('--force')),
        ),
      );
    });
  });

  group('isFlutterAppPubspec', () {
    test('a pubspec with an indented flutter: dependency is a Flutter project', () {
      final pubspec = File(p.join(dir.path, 'pubspec.yaml'))
        ..writeAsStringSync('''
name: my_app
dependencies:
  flutter:
    sdk: flutter
''');

      expect(isFlutterAppPubspec(pubspec), isTrue);
    });

    test('a pure Dart package is not', () {
      final pubspec = File(p.join(dir.path, 'pubspec.yaml'))
        ..writeAsStringSync('''
name: cli_tool
dependencies:
  args: ^2.7.0
''');

      expect(isFlutterAppPubspec(pubspec), isFalse);
    });
  });
}
