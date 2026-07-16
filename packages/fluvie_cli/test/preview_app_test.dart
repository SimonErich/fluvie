import 'dart:io';

import 'package:fluvie_cli/src/cli_failure.dart';
import 'package:fluvie_cli/src/file_target.dart';
import 'package:fluvie_cli/src/preview_app.dart';
import 'package:fluvie_cli/src/process_runner.dart';
import 'package:mocktail/mocktail.dart';
import 'package:path/path.dart' as p;
import 'package:test/test.dart';

class _MockProcessRunner extends Mock implements ProcessRunner {}

void main() {
  setUpAll(() => registerFallbackValue(<String>[]));

  group('previewCacheRoot', () {
    test('prefers XDG_CACHE_HOME when set', () {
      expect(
        previewCacheRoot(environment: const {'XDG_CACHE_HOME': '/xdg', 'HOME': '/home/me'}),
        p.join('/xdg', 'fluvie', 'preview'),
      );
    });

    test('falls back to ~/.cache when XDG is unset', () {
      expect(
        previewCacheRoot(environment: const {'HOME': '/home/me'}),
        p.join('/home/me', '.cache', 'fluvie', 'preview'),
      );
    });

    test('an empty XDG_CACHE_HOME is ignored', () {
      expect(
        previewCacheRoot(environment: const {'XDG_CACHE_HOME': '', 'HOME': '/home/me'}),
        p.join('/home/me', '.cache', 'fluvie', 'preview'),
      );
    });

    test('mirrors the ffmpeg cache layout under fluvie/preview', () {
      // It lives outside the user's project deliberately: a preview app nested
      // in the project would be a second pubspec under the same tree, which
      // breaks resolution in a pub workspace.
      final root = previewCacheRoot(environment: const {'HOME': '/home/me'});

      expect(p.split(root), containsAllInOrder(['fluvie', 'preview']));
      expect(root, isNot(contains('project')));
    });

    test('defaults to the process environment', () {
      expect(previewCacheRoot(), isNotEmpty);
    });
  });

  group('previewAppDir', () {
    const env = {'HOME': '/home/me'};

    test('is a digest directory under the cache root', () {
      final dir = previewAppDir('/projects/my_video', environment: env);

      expect(p.dirname(dir), previewCacheRoot(environment: env));
      expect(p.basename(dir), matches(RegExp(r'^[0-9a-f]{16}$')));
    });

    test('two projects never share an app', () {
      expect(
        previewAppDir('/projects/a', environment: env),
        isNot(previewAppDir('/projects/b', environment: env)),
      );
    });

    test('the same project always gets the same app', () {
      expect(
        previewAppDir('/projects/my_video', environment: env),
        previewAppDir('/projects/my_video', environment: env),
      );
    });

    test('is keyed by the absolute path, not the spelling on the command line', () {
      final relative = previewAppDir('my_video', environment: env);
      final absolute = previewAppDir(
        p.join(Directory.current.path, 'my_video'),
        environment: env,
      );

      expect(relative, absolute);
    });

    test('never lands inside the project it previews', () {
      expect(previewAppDir('/projects/my_video', environment: env), startsWith('/home/me'));
    });
  });

  group('ensurePreviewApp', () {
    late _MockProcessRunner runner;
    late Directory cache;
    late Directory project;
    late Map<String, String> env;
    late StringBuffer out;

    setUp(() {
      runner = _MockProcessRunner();
      // A temp cache root, so no test ever touches the real ~/.cache/fluvie.
      cache = Directory.systemTemp.createTempSync('fluvie_preview_cache_');
      project = Directory.systemTemp.createTempSync('fluvie_preview_project_');
      env = {'XDG_CACHE_HOME': cache.path, 'HOME': cache.path};
      out = StringBuffer();
      File(p.join(project.path, 'pubspec.yaml')).writeAsStringSync('''
name: my_video
dependencies:
  flutter:
    sdk: flutter
  fluvie: ^0.2.0
''');
      addTearDown(() {
        for (final dir in [cache, project]) {
          if (dir.existsSync()) dir.deleteSync(recursive: true);
        }
      });
    });

    /// Stubs `flutter create` to lay down the tree it really would, and
    /// `flutter pub get` to succeed. Nothing is ever spawned.
    void stubFlutter({int createExit = 0, int pubGetExit = 0}) {
      when(
        () => runner.run(
          'flutter',
          any(that: contains('create')),
          workingDirectory: any(named: 'workingDirectory'),
        ),
      ).thenAnswer((invocation) async {
        if (createExit != 0) {
          return ProcessRunResult(exitCode: createExit, stdout: '', stderr: 'create boom');
        }
        final dir = invocation.namedArguments[#workingDirectory] as String;
        Directory(p.join(dir, 'lib')).createSync(recursive: true);
        Directory(p.join(dir, 'linux')).createSync(recursive: true);
        File(p.join(dir, 'test', 'widget_test.dart'))
          ..createSync(recursive: true)
          ..writeAsStringSync('// counter test');
        return const ProcessRunResult(exitCode: 0, stdout: '', stderr: '');
      });
      when(
        () => runner.run(
          'flutter',
          any(that: contains('pub')),
          workingDirectory: any(named: 'workingDirectory'),
        ),
      ).thenAnswer(
        (_) async => ProcessRunResult(
          exitCode: pubGetExit,
          stdout: '',
          stderr: pubGetExit == 0 ? '' : 'pub get boom',
        ),
      );
    }

    /// A target at [relative] inside the temp project.
    FileTarget targetAt(String relative, {String entry = 'build'}) {
      final file = File(p.join(project.path, relative))
        ..createSync(recursive: true)
        ..writeAsStringSync('Video build() => throw 0;');
      return FileTarget(projectDir: project.path, path: file.path, entry: entry);
    }

    Future<String> ensure(FileTarget target, {List<String> platforms = const ['linux']}) =>
        ensurePreviewApp(
          runner: runner,
          target: target,
          platforms: platforms,
          cliVersion: '0.3.0',
          out: out,
          environment: env,
        );

    test('a composition under lib/ is imported by its package URI', () async {
      stubFlutter();

      final dir = await ensure(targetAt(p.join('lib', 'example_video.dart')));

      final main = File(p.join(dir, 'lib', 'main.dart')).readAsStringSync();
      expect(main, contains("import 'package:my_video/example_video.dart' as target;"));
      expect(main, contains('target.build'));
    });

    test('a composition outside lib/ is a stated error naming lib/', () async {
      // The preview app runs outside the project, and a relative import cannot
      // escape a package: the compiler resolves it inside the app's own lib/,
      // so a `../..` climb to another tree fails to read. Say so, rather than
      // emitting an import the compiler cannot resolve.
      stubFlutter();

      await expectLater(
        ensure(targetAt('example_video.dart')),
        throwsA(
          isA<CliFailure>()
              .having((e) => e.message, 'message', contains('must live under lib/'))
              .having((e) => e.message, 'message', contains('example_video.dart'))
              .having((e) => e.message, 'message', contains('fluvie preview ./lib/')),
        ),
      );
    });

    test('the app lands in the temp cache, never inside the project', () async {
      stubFlutter();

      final dir = await ensure(targetAt(p.join('lib', 'example_video.dart')));

      expect(dir, startsWith(cache.path));
      expect(Directory(p.join(project.path, '.fluvie_preview')).existsSync(), isFalse);
    });

    test('the app path-depends on the user project, so pub resolves their fluvie', () async {
      stubFlutter();

      final dir = await ensure(targetAt(p.join('lib', 'example_video.dart')));

      final pubspec = File(p.join(dir, 'pubspec.yaml')).readAsStringSync();
      expect(pubspec, contains('name: fluvie_preview'));
      expect(pubspec, contains('my_video:'));
      expect(pubspec, contains('path: ${project.path}'));
    });

    test('the counter test flutter create leaves behind is removed', () async {
      // It names a widget the preview app does not have, so it would fail a
      // plain `flutter test` in the cache dir.
      stubFlutter();

      final dir = await ensure(targetAt(p.join('lib', 'example_video.dart')));

      expect(File(p.join(dir, 'test', 'widget_test.dart')).existsSync(), isFalse);
    });

    test('a stamped app is reused without scaffolding again', () async {
      stubFlutter();
      final target = targetAt(p.join('lib', 'example_video.dart'));
      final first = await ensure(target);

      final second = await ensure(target);

      expect(second, first);
      verify(
        () => runner.run(
          'flutter',
          any(that: contains('create')),
          workingDirectory: any(named: 'workingDirectory'),
        ),
      ).called(1);
    });

    test('a CLI upgrade rebuilds the app rather than reusing an older template', () async {
      stubFlutter();
      final target = targetAt(p.join('lib', 'example_video.dart'));
      await ensure(target);

      await ensurePreviewApp(
        runner: runner,
        target: target,
        platforms: const ['linux'],
        cliVersion: '0.4.0',
        out: out,
        environment: env,
      );

      verify(
        () => runner.run(
          'flutter',
          any(that: contains('create')),
          workingDirectory: any(named: 'workingDirectory'),
        ),
      ).called(2);
    });

    test('a different entry rebuilds the app', () async {
      stubFlutter();
      await ensure(targetAt(p.join('lib', 'example_video.dart')));

      await ensure(targetAt(p.join('lib', 'example_video.dart'), entry: 'introClipVideo'));

      verify(
        () => runner.run(
          'flutter',
          any(that: contains('create')),
          workingDirectory: any(named: 'workingDirectory'),
        ),
      ).called(2);
    });

    test('a missing platform directory rebuilds the app', () async {
      stubFlutter();
      final target = targetAt(p.join('lib', 'example_video.dart'));
      await ensure(target);

      // The same project previewed on the web needs a web/ the linux app has not
      // got, so `flutter run` would be hard-gated on a directory that is absent.
      await ensure(target, platforms: const ['web']);

      verify(
        () => runner.run(
          'flutter',
          any(that: contains('create')),
          workingDirectory: any(named: 'workingDirectory'),
        ),
      ).called(2);
    });

    test('a failed flutter create is a CliFailure carrying its output', () async {
      stubFlutter(createExit: 1);

      await expectLater(
        ensure(targetAt(p.join('lib', 'example_video.dart'))),
        throwsA(
          isA<CliFailure>()
              .having((e) => e.message, 'message', contains('Could not scaffold'))
              .having((e) => e.message, 'message', contains('create boom')),
        ),
      );
    });

    test('a failed pub get is a CliFailure', () async {
      stubFlutter(pubGetExit: 1);

      await expectLater(
        ensure(targetAt(p.join('lib', 'example_video.dart'))),
        throwsA(
          isA<CliFailure>().having(
            (e) => e.message,
            'message',
            contains('Could not resolve the preview app dependencies'),
          ),
        ),
      );
    });

    test('a project with no package name is a CliFailure', () async {
      stubFlutter();
      File(p.join(project.path, 'pubspec.yaml')).writeAsStringSync('description: nameless\n');

      await expectLater(
        ensure(targetAt(p.join('lib', 'example_video.dart'))),
        throwsA(
          isA<CliFailure>().having((e) => e.message, 'message', contains('no package name')),
        ),
      );
    });

    test('the project assets are linked into the app so Flutter bundles them', () async {
      // Symlinked rather than declared with a `../` path: Flutter follows
      // symlinks when it bundles, while a `../` asset entry is accepted and then
      // silently written outside the bundle.
      stubFlutter();
      File(p.join(project.path, 'assets', 'images', 'hero.png'))
        ..createSync(recursive: true)
        ..writeAsBytesSync(const [0]);

      final dir = await ensure(targetAt(p.join('lib', 'example_video.dart')));

      expect(
        File(p.join(dir, 'assets', 'images', 'hero.png')).existsSync(),
        isTrue,
        reason: 'the asset must be readable through the app directory',
      );
      final pubspec = File(p.join(dir, 'pubspec.yaml')).readAsStringSync();
      expect(pubspec, contains('assets/'));
      expect(pubspec, contains('assets/images/'));
    });

    test('reports that it is preparing the app on the first run', () async {
      stubFlutter();

      await ensure(targetAt(p.join('lib', 'example_video.dart')));

      expect(out.toString(), contains('Preparing the preview app'));
    });
  });
}
