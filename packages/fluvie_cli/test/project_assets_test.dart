import 'dart:io';

import 'package:fluvie_cli/src/project_assets.dart';
import 'package:path/path.dart' as p;
import 'package:test/test.dart';

void main() {
  late Directory project;

  setUp(() {
    project = Directory.systemTemp.createTempSync('fluvie_assets_');
    addTearDown(() {
      if (project.existsSync()) project.deleteSync(recursive: true);
    });
  });

  /// Writes an empty asset file at [relative] (under the project root).
  void asset(String relative) => File(p.join(project.path, relative))
    ..createSync(recursive: true)
    ..writeAsBytesSync(const [0]);

  void writePubspec(String body) =>
      File(p.join(project.path, 'pubspec.yaml')).writeAsStringSync(body);

  String readPubspec() => File(p.join(project.path, 'pubspec.yaml')).readAsStringSync();

  group('assetDirEntries', () {
    test('a project with no assets directory has no entries', () {
      expect(assetDirEntries(project.path), isEmpty);
    });

    test('an empty assets directory has no entries', () {
      Directory(p.join(project.path, 'assets')).createSync();

      expect(assetDirEntries(project.path), isEmpty);
    });

    test('files directly in assets/ get the assets/ entry', () {
      asset(p.join('assets', 'logo.png'));

      expect(assetDirEntries(project.path), ['assets/']);
    });

    test('every nested directory holding files gets its own entry', () {
      // The crux: Flutter enumerates a declared asset directory with a
      // NON-recursive listSync, so `assets/` alone bundles only what sits
      // directly in it and assets/images/logo.png is silently missing at
      // runtime, with no build error.
      asset(p.join('assets', 'logo.png'));
      asset(p.join('assets', 'images', 'hero.png'));
      asset(p.join('assets', 'images', 'icons', 'star.png'));
      asset(p.join('assets', 'audio', 'bed.wav'));

      expect(assetDirEntries(project.path), [
        'assets/',
        'assets/audio/',
        'assets/images/',
        'assets/images/icons/',
      ]);
    });

    test('a directory holding only subdirectories gets no entry', () {
      // An entry for it would bundle nothing.
      asset(p.join('assets', 'images', 'nested', 'hero.png'));

      expect(assetDirEntries(project.path), ['assets/images/nested/']);
    });

    test('resolution variant directories are skipped', () {
      // A variant's files are bundled through their base asset, so declaring
      // the variant directory would be redundant.
      asset(p.join('assets', 'images', 'hero.png'));
      asset(p.join('assets', 'images', '2.0x', 'hero.png'));
      asset(p.join('assets', 'images', '3.0x', 'hero.png'));

      expect(assetDirEntries(project.path), ['assets/images/']);
    });

    test('a variant directory is skipped even when it is the only content', () {
      asset(p.join('assets', 'images', '2.0x', 'hero.png'));

      expect(assetDirEntries(project.path), isEmpty);
    });

    test('a directory whose name merely starts with a digit is not a variant', () {
      asset(p.join('assets', '2024_recap', 'clip.png'));

      expect(assetDirEntries(project.path), ['assets/2024_recap/']);
    });

    test('the order is stable and sorted', () {
      asset(p.join('assets', 'zulu', 'z.png'));
      asset(p.join('assets', 'alpha', 'a.png'));
      asset(p.join('assets', 'mike', 'm.png'));

      expect(assetDirEntries(project.path), [
        'assets/alpha/',
        'assets/mike/',
        'assets/zulu/',
      ]);
    });
  });

  group('syncAssetsBlock', () {
    test('adds the flutter: assets: block when the pubspec has no flutter section', () {
      writePubspec('name: demo\ndependencies:\n  fluvie: ^0.2.0\n');
      asset(p.join('assets', 'images', 'hero.png'));

      expect(syncAssetsBlock(project.path), isTrue);
      expect(readPubspec(), contains('assets/images/'));
    });

    test('rewrites the block in place without disturbing the rest of the pubspec', () {
      writePubspec('''
name: demo
description: A Fluvie video project.
dependencies:
  flutter:
    sdk: flutter
  fluvie: ^0.2.0

flutter:
  uses-material-design: true
  assets:
    - assets/stale/
''');
      asset(p.join('assets', 'images', 'hero.png'));

      expect(syncAssetsBlock(project.path), isTrue);
      final pubspec = readPubspec();
      expect(pubspec, contains('assets/images/'));
      expect(pubspec, isNot(contains('assets/stale/')));
      // Everything the CLI does not own survives untouched.
      expect(pubspec, contains('name: demo'));
      expect(pubspec, contains('description: A Fluvie video project.'));
      expect(pubspec, contains('fluvie: ^0.2.0'));
      expect(pubspec, contains('uses-material-design: true'));
    });

    test('a project with no assets gets no block', () {
      writePubspec('name: demo\ndependencies:\n  fluvie: ^0.2.0\n');

      expect(syncAssetsBlock(project.path), isFalse);
      expect(readPubspec(), isNot(contains('assets')));
    });

    test('an existing block is removed once the assets are gone', () {
      writePubspec('''
name: demo

flutter:
  uses-material-design: true
  assets:
    - assets/images/
''');

      expect(syncAssetsBlock(project.path), isTrue);
      final pubspec = readPubspec();
      expect(pubspec, isNot(contains('assets/images/')));
      expect(pubspec, contains('uses-material-design: true'));
    });

    test('is idempotent: a second run reports no change', () {
      writePubspec('name: demo\ndependencies:\n  fluvie: ^0.2.0\n');
      asset(p.join('assets', 'logo.png'));
      asset(p.join('assets', 'images', 'hero.png'));

      expect(syncAssetsBlock(project.path), isTrue);
      final afterFirst = readPubspec();

      expect(syncAssetsBlock(project.path), isFalse);
      expect(readPubspec(), afterFirst);
    });

    test('a new nested asset directory is picked up on the next run', () {
      writePubspec('name: demo\n');
      asset(p.join('assets', 'logo.png'));
      syncAssetsBlock(project.path);

      // Dropping assets/images/hero.png in needs no pubspec edit by hand, which
      // is the whole point of the CLI owning the block.
      asset(p.join('assets', 'images', 'hero.png'));

      expect(syncAssetsBlock(project.path), isTrue);
      expect(readPubspec(), contains('assets/images/'));
    });

    test('a project with no pubspec is left alone', () {
      asset(p.join('assets', 'logo.png'));

      expect(syncAssetsBlock(project.path), isFalse);
    });
  });
}
