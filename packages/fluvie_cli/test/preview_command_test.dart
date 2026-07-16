import 'dart:io';

import 'package:fluvie_cli/src/cli_failure.dart';
import 'package:fluvie_cli/src/file_target.dart';
import 'package:fluvie_cli/src/preview_command.dart';
import 'package:path/path.dart' as p;
import 'package:test/test.dart';

void main() {
  late Directory project;
  late String composition;
  late StringBuffer out;
  late StringBuffer err;

  setUp(() {
    project = Directory.systemTemp.createTempSync('fluvie_preview_');
    File(p.join(project.path, 'pubspec.yaml')).writeAsStringSync('''
name: my_video
dependencies:
  flutter:
    sdk: flutter
  fluvie: ^0.2.0
''');
    // Under lib/, which is where `fluvie init` scaffolds it and the only place
    // a previewed composition can live: the preview app runs outside the
    // project and reaches it by its package URI.
    composition = p.join(project.path, 'lib', 'example_video.dart');
    File(composition)
      ..createSync(recursive: true)
      ..writeAsStringSync('Video build() => throw 0;');
    out = StringBuffer();
    err = StringBuffer();
    addTearDown(() {
      if (project.existsSync()) project.deleteSync(recursive: true);
    });
  });

  group('defaultPreviewDevice', () {
    test('is the host desktop', () {
      final expected = switch (Platform.operatingSystem) {
        'linux' => 'linux',
        'macos' => 'macos',
        'windows' => 'windows',
        _ => 'chrome',
      };

      expect(defaultPreviewDevice(), expected);
    });

    test('is never the browser on a desktop host', () {
      // A desktop preview decodes any clip through ffmpeg, while the browser can
      // only decode what WebCodecs supports (no ProRes, the one format that
      // carries alpha), so a browser default would show a placeholder for
      // exactly the compositions people care most about.
      if (!Platform.isLinux && !Platform.isMacOS && !Platform.isWindows) return;

      expect(defaultPreviewDevice(), isNot('chrome'));
      expect(platformsFor(defaultPreviewDevice()), isNot(contains('web')));
    });
  });

  group('platformsFor', () {
    test('a browser device needs the web directory', () {
      expect(platformsFor('chrome'), ['web']);
      expect(platformsFor('web-server'), ['web']);
    });

    test('each desktop device needs its own platform directory', () {
      expect(platformsFor('linux'), ['linux']);
      expect(platformsFor('macos'), ['macos']);
      expect(platformsFor('windows'), ['windows']);
    });

    test('an unknown device is a real one, so the mobile platforms are scaffolded', () {
      // A phone or an emulator id: scaffold both and let `flutter run` match.
      expect(platformsFor('00008030-001A2C3D'), ['android', 'ios']);
      expect(platformsFor('emulator-5554'), ['android', 'ios']);
    });
  });

  group('PreviewCommand', () {
    /// A preview command whose app scaffolding is replaced by [onCall], so no
    /// test ever spawns `flutter` or touches the real preview cache.
    PreviewCommand command({
      void Function({required FileTarget target, required List<String> platforms})? onCall,
    }) => PreviewCommand(
      ensureApp:
          ({
            required runner,
            required target,
            required platforms,
            required cliVersion,
            required out,
            environment,
          }) async {
            onCall?.call(target: target, platforms: platforms);
            // Stop before `flutter run`: the interactive spawn is out of a unit
            // test's reach, and everything under test has already happened.
            throw const CliFailure('stopped before flutter run');
          },
    );

    Future<int> execute(
      List<String> args, {
      void Function({required FileTarget target, required List<String> platforms})? onCall,
    }) => command(
      onCall: onCall,
    ).execute(PreviewCommand.buildParser().parse(args), out: out, err: err);

    test('needs exactly one composition file', () async {
      expect(await execute(const []), 64);
      expect(err.toString(), contains('exactly one composition file'));
    });

    test('two positionals are a usage error', () async {
      expect(await execute([composition, composition]), 64);
    });

    test('a missing composition file is exit 1 with a stated reason', () async {
      expect(await execute(const ['no_such_file.dart']), 1);
      expect(err.toString(), contains('No such composition file'));
    });

    test('resolves the target and its project before scaffolding the app', () async {
      FileTarget? seen;

      await execute([
        composition,
      ], onCall: ({required target, required platforms}) => seen = target);

      expect(seen?.path, composition);
      expect(seen?.projectDir, project.path);
      expect(seen?.entry, 'build');
    });

    test('--entry names the top-level function returning the Video', () async {
      FileTarget? seen;

      await execute(
        [composition, '--entry', 'introClipVideo'],
        onCall: ({required target, required platforms}) => seen = target,
      );

      expect(seen?.entry, 'introClipVideo');
    });

    test('-d drives the scaffolded platforms', () async {
      List<String>? seen;

      await execute(
        [composition, '-d', 'chrome'],
        onCall: ({required target, required platforms}) => seen = platforms,
      );

      expect(seen, ['web']);
    });

    test('without -d the host desktop platform is scaffolded', () async {
      List<String>? seen;

      await execute([
        composition,
      ], onCall: ({required target, required platforms}) => seen = platforms);

      expect(seen, platformsFor(defaultPreviewDevice()));
    });

    test('--project overrides the discovered project', () async {
      FileTarget? seen;

      await execute(
        [composition, '--project', '/somewhere/else'],
        onCall: ({required target, required platforms}) => seen = target,
      );

      expect(seen?.projectDir, '/somewhere/else');
    });

    test('syncs the pubspec assets block before previewing', () async {
      // Dropping assets/images/hero.png in needs no pubspec edit by hand.
      File(p.join(project.path, 'assets', 'images', 'hero.png'))
        ..createSync(recursive: true)
        ..writeAsBytesSync(const [0]);

      await execute([composition]);

      expect(
        File(p.join(project.path, 'pubspec.yaml')).readAsStringSync(),
        contains('assets/images/'),
      );
    });

    test('a CliFailure while preparing the app is exit 1, not a raw throw', () async {
      expect(await execute([composition]), 1);
      expect(err.toString(), contains('stopped before flutter run'));
    });
  });
}
