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
    ///
    /// [blockAssetSymlink] leaves a real `assets/` directory in the app, which
    /// makes the symlink `_linkAssets` tries fail exactly as it does on a
    /// Windows host without Developer Mode.
    void stubFlutter({int createExit = 0, int pubGetExit = 0, bool blockAssetSymlink = false}) {
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
        if (blockAssetSymlink) Directory(p.join(dir, 'assets')).createSync(recursive: true);
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

    test('the linked assets are the project files themselves, not a stale copy', () async {
      // A symlink is what keeps an edited asset live in the running preview.
      stubFlutter();
      final asset = File(p.join(project.path, 'assets', 'hero.txt'))
        ..createSync(recursive: true)
        ..writeAsStringSync('first');

      final dir = await ensure(targetAt(p.join('lib', 'example_video.dart')));
      asset.writeAsStringSync('second');

      expect(File(p.join(dir, 'assets', 'hero.txt')).readAsStringSync(), 'second');
      expect(Link(p.join(dir, 'assets')).existsSync(), isTrue);
    });

    test('assets are copied when a symlink cannot be created', () async {
      // Windows needs Developer Mode or elevation for a symlink; a copy bundles
      // the same bytes, it just goes stale until the next scaffold.
      stubFlutter(blockAssetSymlink: true);
      File(p.join(project.path, 'assets', 'images', 'hero.png'))
        ..createSync(recursive: true)
        ..writeAsBytesSync(const [7]);

      final dir = await ensure(targetAt(p.join('lib', 'example_video.dart')));

      final copied = File(p.join(dir, 'assets', 'images', 'hero.png'));
      expect(copied.existsSync(), isTrue, reason: 'the fallback must still bundle the bytes');
      expect(copied.readAsBytesSync(), const [7]);
      expect(Link(p.join(dir, 'assets')).existsSync(), isFalse);
    });

    test('a project with no assets directory links nothing and declares nothing', () async {
      stubFlutter();

      final dir = await ensure(targetAt(p.join('lib', 'example_video.dart')));

      expect(Directory(p.join(dir, 'assets')).existsSync(), isFalse);
      expect(File(p.join(dir, 'pubspec.yaml')).readAsStringSync(), isNot(contains('- assets/')));
    });

    test('reports that it is preparing the app on the first run', () async {
      stubFlutter();

      await ensure(targetAt(p.join('lib', 'example_video.dart')));

      expect(out.toString(), contains('Preparing the preview app'));
    });
  });

  group('ensurePreviewApp dependency_overrides', () {
    // pub applies dependency_overrides only from the root package of a
    // resolution, and the preview app IS that root. Without copying them, a
    // contributor who path-overrides fluvie previews against the published
    // package while their renders use the local one: the same composition,
    // different pixels.
    late _MockProcessRunner runner;
    late Directory cache;
    late Map<String, String> env;
    late StringBuffer out;

    setUp(() {
      runner = _MockProcessRunner();
      cache = Directory.systemTemp.createTempSync('fluvie_preview_ovr_cache_');
      env = {'XDG_CACHE_HOME': cache.path, 'HOME': cache.path};
      out = StringBuffer();
      when(
        () => runner.run('flutter', any(), workingDirectory: any(named: 'workingDirectory')),
      ).thenAnswer((invocation) async {
        final dir = invocation.namedArguments[#workingDirectory] as String;
        Directory(p.join(dir, 'lib')).createSync(recursive: true);
        Directory(p.join(dir, 'linux')).createSync(recursive: true);
        return const ProcessRunResult(exitCode: 0, stdout: '', stderr: '');
      });
      addTearDown(() {
        if (cache.existsSync()) cache.deleteSync(recursive: true);
      });
    });

    /// A project directory holding [pubspec], plus a composition under `lib/`.
    /// Extra files (a `pubspec_overrides.yaml`) come from [extraFiles].
    Directory projectWith(String pubspec, {Map<String, String> extraFiles = const {}}) {
      final dir = Directory.systemTemp.createTempSync('fluvie_preview_ovr_project_');
      addTearDown(() {
        if (dir.existsSync()) dir.deleteSync(recursive: true);
      });
      File(p.join(dir.path, 'pubspec.yaml')).writeAsStringSync(pubspec);
      extraFiles.forEach(
        (name, content) => File(p.join(dir.path, name)).writeAsStringSync(content),
      );
      File(p.join(dir.path, 'lib', 'example_video.dart'))
        ..createSync(recursive: true)
        ..writeAsStringSync('Video build() => throw 0;');
      return dir;
    }

    /// The generated preview app's pubspec for the project at [dir].
    Future<String> appPubspecFor(Directory dir) async {
      final appDir = await ensurePreviewApp(
        runner: runner,
        target: FileTarget(
          projectDir: dir.path,
          path: p.join(dir.path, 'lib', 'example_video.dart'),
          entry: 'build',
        ),
        platforms: const ['linux'],
        cliVersion: '0.3.0',
        out: out,
        environment: env,
      );
      return File(p.join(appDir, 'pubspec.yaml')).readAsStringSync();
    }

    const base = '''
name: my_video
dependencies:
  flutter:
    sdk: flutter
  fluvie: ^0.2.0
''';

    test('no overrides means no dependency_overrides block at all', () async {
      final pubspec = await appPubspecFor(projectWith(base));

      expect(pubspec, isNot(contains('dependency_overrides')));
    });

    test('a path override in the project pubspec is copied into the app', () async {
      final pubspec = await appPubspecFor(
        projectWith('''
$base
dependency_overrides:
  fluvie:
    path: /work/fluvie/packages/fluvie
'''),
      );

      expect(pubspec, contains('dependency_overrides:'));
      expect(pubspec, contains('fluvie:'));
      expect(pubspec, contains('path: /work/fluvie/packages/fluvie'));
    });

    test('a relative override path is rewritten absolute, resolved against the project', () async {
      // The app lives in the cache, not next to the project, so a copied `../`
      // would resolve from the wrong directory and point at nothing.
      final project = projectWith('''
$base
dependency_overrides:
  fluvie:
    path: ../fluvie_local/packages/fluvie
''');

      final pubspec = await appPubspecFor(project);

      final expected = p.normalize(
        p.join(project.path, '..', 'fluvie_local', 'packages', 'fluvie'),
      );
      expect(pubspec, contains('path: $expected'));
      expect(p.isAbsolute(expected), isTrue);
      expect(pubspec, isNot(contains('path: ../')));
    });

    test('a version-string override is copied through as written', () async {
      final pubspec = await appPubspecFor(
        projectWith('''
$base
dependency_overrides:
  meta: ^1.16.0
'''),
      );

      expect(pubspec, contains('meta: ^1.16.0'));
    });

    test('an override in pubspec_overrides.yaml is copied too', () async {
      // The file pub reads for a member's local overrides, so it carries exactly
      // the override a contributor is previewing against.
      // The override target is named so it cannot prefix-match the project's own
      // path dependency line, which would pass this test without reading the
      // file at all.
      final project = projectWith(
        base,
        extraFiles: const {
          'pubspec_overrides.yaml':
              'dependency_overrides:\n  fluvie:\n    path: ../local_checkout/fluvie\n',
        },
      );

      final pubspec = await appPubspecFor(project);

      expect(
        pubspec,
        contains('path: ${p.normalize(p.join(project.path, '..', 'local_checkout', 'fluvie'))}'),
      );
    });

    test('a workspace root supplies the overrides, because pub requires them there', () async {
      // A workspace member's own pubspec cannot carry dependency_overrides: pub
      // rejects them anywhere but the root. Fluvie's own repo is a workspace, so
      // reading only the project's pubspec would miss every contributor's
      // override.
      final root = Directory.systemTemp.createTempSync('fluvie_preview_ws_');
      addTearDown(() {
        if (root.existsSync()) root.deleteSync(recursive: true);
      });
      File(p.join(root.path, 'pubspec.yaml')).writeAsStringSync('''
name: workspace_root
workspace:
  - member
dependency_overrides:
  fluvie:
    path: packages/fluvie
''');
      final member = Directory(p.join(root.path, 'member'))..createSync(recursive: true);
      File(p.join(member.path, 'pubspec.yaml')).writeAsStringSync('''
name: my_video
resolution: workspace
dependencies:
  flutter:
    sdk: flutter
''');
      File(p.join(member.path, 'lib', 'example_video.dart'))
        ..createSync(recursive: true)
        ..writeAsStringSync('Video build() => throw 0;');

      final pubspec = await appPubspecFor(member);

      expect(pubspec, contains('path: ${p.join(root.path, 'packages', 'fluvie')}'));
    });

    test('an ancestor without a workspace key contributes no overrides', () async {
      // A plain parent directory that happens to hold a pubspec is not a
      // workspace root, and pub would never apply its overrides to the member.
      final root = Directory.systemTemp.createTempSync('fluvie_preview_nows_');
      addTearDown(() {
        if (root.existsSync()) root.deleteSync(recursive: true);
      });
      File(p.join(root.path, 'pubspec.yaml')).writeAsStringSync('''
name: unrelated_parent
dependency_overrides:
  fluvie:
    path: packages/fluvie
''');
      final nested = Directory(p.join(root.path, 'member'))..createSync(recursive: true);
      File(p.join(nested.path, 'pubspec.yaml')).writeAsStringSync(base);
      File(p.join(nested.path, 'lib', 'example_video.dart'))
        ..createSync(recursive: true)
        ..writeAsStringSync('Video build() => throw 0;');

      final pubspec = await appPubspecFor(nested);

      expect(pubspec, isNot(contains('dependency_overrides')));
    });
  });
}
