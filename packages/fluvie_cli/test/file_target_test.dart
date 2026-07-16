import 'dart:io';

import 'package:fluvie_cli/src/cli_failure.dart';
import 'package:fluvie_cli/src/file_target.dart';
import 'package:path/path.dart' as p;
import 'package:test/test.dart';

void main() {
  Directory tempDir(String prefix) {
    final dir = Directory.systemTemp.createTempSync(prefix);
    addTearDown(() {
      if (dir.existsSync()) dir.deleteSync(recursive: true);
    });
    return dir;
  }

  /// A project directory with a pubspec named [name] and a composition at
  /// [relative], returned as an absolute path pair.
  ({String project, String path}) project(String relative, {String? name = 'my_app'}) {
    final dir = tempDir('fluvie_target_');
    File(p.join(dir.path, 'pubspec.yaml')).writeAsStringSync(
      name == null ? 'description: nameless\n' : 'name: $name\n',
    );
    final file = File(p.join(dir.path, relative))
      ..createSync(recursive: true)
      ..writeAsStringSync('Video build() => throw 0;');
    return (project: dir.path, path: file.path);
  }

  group('FileTarget.packageUri', () {
    test('a composition under lib/ has a package: URI', () {
      final target = project(p.join('lib', 'videos', 'hero.dart'));

      expect(
        FileTarget(projectDir: target.project, path: target.path, entry: 'build').packageUri,
        'package:my_app/videos/hero.dart',
      );
    });

    test('a composition at the project root has none', () {
      // A file outside lib/ has no package URI at all, so only an importer
      // inside the same package can reach it.
      final target = project('example_video.dart');

      expect(
        FileTarget(projectDir: target.project, path: target.path, entry: 'build').packageUri,
        isNull,
      );
    });

    test('a composition in a sibling directory of lib/ has none', () {
      final target = project(p.join('clips', 'hero.dart'));

      expect(
        FileTarget(projectDir: target.project, path: target.path, entry: 'build').packageUri,
        isNull,
      );
    });

    test('a lib/ composition in a package with no name has none', () {
      final target = project(p.join('lib', 'hero.dart'), name: null);

      expect(
        FileTarget(projectDir: target.project, path: target.path, entry: 'build').packageUri,
        isNull,
      );
    });

    test('is a URI with forward slashes, never a host path', () {
      final target = project(p.join('lib', 'a', 'b', 'hero.dart'));

      final uri = FileTarget(
        projectDir: target.project,
        path: target.path,
        entry: 'build',
      ).packageUri;

      expect(uri, 'package:my_app/a/b/hero.dart');
      expect(uri, isNot(contains(r'\')));
    });
  });

  group('FileTarget.importFrom', () {
    test('a root-level composition is reached by a relative import', () {
      // A file outside lib/ has no `package:` URI at all, so a relative import
      // is the only identity it can have.
      final target = project('example_video.dart');
      final file = FileTarget(
        projectDir: target.project,
        path: target.path,
        entry: 'build',
      );

      expect(
        file.importFrom(p.join(target.project, '.fluvie', 'example_video_dart')),
        '../../example_video.dart',
      );
    });

    test('a composition under lib/ is reached by its package: URI', () {
      // The double-library-identity trap: a relative import would give the same
      // file a second library identity, so its `Video` would not be the `Video`
      // the harness expects, and it trips avoid_relative_lib_imports.
      final target = project(p.join('lib', 'videos', 'hero.dart'));
      final file = FileTarget(
        projectDir: target.project,
        path: target.path,
        entry: 'build',
      );

      expect(
        file.importFrom(p.join(target.project, '.fluvie', 'lib_videos_hero_dart')),
        'package:my_app/videos/hero.dart',
      );
    });

    test('a lib/ composition falls back to a relative import when the package has no name', () {
      final target = project(p.join('lib', 'hero.dart'), name: null);
      final file = FileTarget(
        projectDir: target.project,
        path: target.path,
        entry: 'build',
      );

      expect(file.importFrom(p.join(target.project, 'lib')), 'hero.dart');
    });

    test('a file beside the harness imports it by bare name', () {
      final target = project('input.dart');
      final file = FileTarget(
        projectDir: target.project,
        path: target.path,
        entry: 'build',
      );

      expect(file.importFrom(target.project), 'input.dart');
    });

    test('the import is a URI with forward slashes, never a host path', () {
      // Built with the path package and joined as a URI: an import URI uses
      // forward slashes on every platform, including Windows.
      final target = project(p.join('clips', 'nested', 'deep', 'hero.dart'));
      final file = FileTarget(
        projectDir: target.project,
        path: target.path,
        entry: 'build',
      );

      final import = file.importFrom(p.join(target.project, '.fluvie', 'slug'));
      expect(import, '../../clips/nested/deep/hero.dart');
      expect(import, isNot(contains(r'\')));
    });
  });

  group('isFileTarget', () {
    test('a .dart suffix is a file target', () {
      expect(isFileTarget('./example_video.dart'), isTrue);
      expect(isFileTarget('lib/videos/hero.dart'), isTrue);
    });

    test('an existing file is a file target even without the suffix', () {
      final dir = tempDir('fluvie_is_target_');
      final file = File(p.join(dir.path, 'composition'))..writeAsStringSync('');

      expect(isFileTarget(file.path), isTrue);
    });

    test('a bare registry key is not a file target', () {
      // `fluvie render starter` must keep resolving through the registry.
      expect(isFileTarget('starter'), isFalse);
      expect(isFileTarget('04_scenes_and_transitions'), isFalse);
    });
  });

  group('resolveFileTarget', () {
    test('resolves the file, its project, and the entry', () {
      final target = project('example_video.dart');

      final resolved = resolveFileTarget(arg: target.path, entry: 'build');

      expect(resolved.path, target.path);
      expect(resolved.projectDir, target.project);
      expect(resolved.entry, 'build');
    });

    test('an explicit project overrides the discovered one', () {
      final target = project('example_video.dart');

      final resolved = resolveFileTarget(
        arg: target.path,
        entry: 'build',
        project: '/somewhere/else',
      );

      expect(resolved.projectDir, '/somewhere/else');
    });

    test('finds the project by walking up from the file', () {
      final target = project(p.join('clips', 'nested', 'hero.dart'));

      expect(resolveFileTarget(arg: target.path, entry: 'build').projectDir, target.project);
    });

    test('a ./ segment leaves no /. in the resolved paths', () {
      // `fluvie render ./my_clip.dart` is how the scaffold tells people to run
      // it, and the project path is both printed and staged into.
      final target = project('my_clip.dart');
      final dotted = p.join(target.project, '.', 'my_clip.dart');

      final resolved = resolveFileTarget(arg: dotted, entry: 'build');

      expect(resolved.path, target.path);
      expect(resolved.projectDir, target.project);
      expect(resolved.path, isNot(contains('/./')));
      expect(resolved.projectDir, isNot(endsWith('/.')));
    });

    test('an explicit --project is normalized too', () {
      final target = project('my_clip.dart');

      final resolved = resolveFileTarget(
        arg: target.path,
        entry: 'build',
        project: p.join(target.project, '.'),
      );

      expect(resolved.projectDir, target.project);
    });

    test('a missing file fails with a stated reason', () {
      expect(
        () => resolveFileTarget(arg: 'no_such_file.dart', entry: 'build'),
        throwsA(
          isA<CliFailure>().having(
            (e) => e.message,
            'message',
            contains('No such composition file'),
          ),
        ),
      );
    });

    test(
      'a file with no pubspec above it fails with a `fluvie init` hint',
      () {
        final dir = tempDir('fluvie_no_project_');
        final orphan = File(p.join(dir.path, 'lonely.dart'))..writeAsStringSync('');

        expect(
          () => resolveFileTarget(arg: orphan.path, entry: 'build'),
          throwsA(
            isA<CliFailure>()
                .having((e) => e.message, 'message', contains('No pubspec.yaml'))
                .having((e) => e.message, 'message', contains('fluvie init')),
          ),
        );
      },
      skip: _systemTempHasAPubspecAbove ? 'systemTemp sits under a pub package' : null,
    );
  });

  group('packageNameOf', () {
    test('reads the package name', () {
      final target = project('example_video.dart', name: 'cool_clip');

      expect(packageNameOf(target.project), 'cool_clip');
    });

    test('is null without a pubspec', () {
      expect(packageNameOf(tempDir('fluvie_no_pubspec_').path), isNull);
    });

    test('is null when the pubspec declares no name', () {
      final target = project('example_video.dart', name: null);

      expect(packageNameOf(target.project), isNull);
    });

    test('ignores an indented name: (a dependency key, not the package)', () {
      final dir = tempDir('fluvie_indented_name_');
      File(p.join(dir.path, 'pubspec.yaml')).writeAsStringSync(
        'dependencies:\n  name: not_the_package\n',
      );

      expect(packageNameOf(dir.path), isNull);
    });
  });
}

/// Whether the system temp directory happens to sit inside a pub package, which
/// would give an orphan composition a pubspec above it after all.
bool get _systemTempHasAPubspecAbove {
  var dir = Directory.systemTemp.absolute.path;
  while (true) {
    if (File(p.join(dir, 'pubspec.yaml')).existsSync()) return true;
    final parent = p.dirname(dir);
    if (parent == dir) return false;
    dir = parent;
  }
}
