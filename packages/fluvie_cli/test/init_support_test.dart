import 'dart:io';

import 'package:fluvie_cli/src/init_support.dart';
import 'package:test/test.dart';

void main() {
  group('scaffold version pins', () {
    test('track the release version so a fresh project resolves the current fluvie', () {
      // `fluvie init` writes these caret pins; if they lag the release, a new
      // project pulls an older fluvie whose surface the generated harness (which
      // imports package:fluvie/rendering.dart) does not have.
      final pubspec = File('pubspec.yaml').readAsStringSync();
      final version = RegExp(r'^version:\s*(.+)$', multiLine: true).firstMatch(pubspec)!.group(1)!;
      expect(fluvieDependencyVersion, '^${version.trim()}');
      expect(fluvieLintsDependencyVersion, '^${version.trim()}');
    });
  });

  group('compositionSlug', () {
    test('a single lowercase word is already a slug', () {
      expect(compositionSlug('starter'), 'starter');
    });

    test('a multi-word name folds to a snake_case slug', () {
      expect(compositionSlug('Intro Clip'), 'intro_clip');
    });

    test('every non-alphanumeric run folds to one underscore', () {
      expect(compositionSlug('Hero  --  Shot!'), 'hero_shot');
      expect(compositionSlug(r'a/b\c.d'), 'a_b_c_d');
    });

    test('a leading digit is prefixed so the slug names an importable library', () {
      // The slug names a file under lib/, which other Dart imports by its
      // package URI, and a library name cannot start with a digit.
      expect(compositionSlug('123 go'), 'v123_go');
    });

    test('an empty name falls back to example_video', () {
      expect(compositionSlug(''), 'example_video');
      expect(compositionSlug('  '), 'example_video');
      expect(compositionSlug('---'), 'example_video');
    });
  });

  group('writeFileIfAbsent', () {
    late Directory dir;
    setUp(() => dir = Directory.systemTemp.createTempSync('fluvie_write_'));
    tearDown(() => dir.deleteSync(recursive: true));

    test('writes a new file and creates parent dirs', () {
      final file = File('${dir.path}/a/b/c.dart');
      expect(writeFileIfAbsent(file, 'x', force: false), isTrue);
      expect(file.readAsStringSync(), 'x');
    });

    test('skips an existing file unless forced', () {
      final file = File('${dir.path}/c.dart')..writeAsStringSync('old');
      expect(writeFileIfAbsent(file, 'new', force: false), isFalse);
      expect(file.readAsStringSync(), 'old');
      expect(writeFileIfAbsent(file, 'new', force: true), isTrue);
      expect(file.readAsStringSync(), 'new');
    });
  });

  group('ensureCustomLintPlugin', () {
    late Directory dir;
    late File options;

    setUp(() {
      dir = Directory.systemTemp.createTempSync('fluvie_lints_wire_');
      options = File('${dir.path}/analysis_options.yaml');
    });

    tearDown(() => dir.deleteSync(recursive: true));

    test('creates analysis_options.yaml with the plugin when absent', () {
      expect(ensureCustomLintPlugin(options), isTrue);
      final content = options.readAsStringSync();
      expect(content, contains('include: package:flutter_lints/flutter.yaml'));
      expect(content, contains('custom_lint'));
    });

    test('adds the plugin to an existing options file, preserving it', () {
      options.writeAsStringSync('include: package:flutter_lints/flutter.yaml\n');
      expect(ensureCustomLintPlugin(options), isTrue);
      final content = options.readAsStringSync();
      expect(content, contains('include: package:flutter_lints/flutter.yaml'));
      expect(content, contains('custom_lint'));
    });

    test('is a no-op when the plugin is already wired', () {
      options.writeAsStringSync(
        'analyzer:\n  plugins:\n    - custom_lint\n',
      );
      expect(ensureCustomLintPlugin(options), isFalse);
    });

    test('adds a plugins list to an analyzer block that has none, keeping its keys', () {
      options.writeAsStringSync('analyzer:\n  exclude:\n    - build/**\n');

      expect(ensureCustomLintPlugin(options), isTrue);
      final content = options.readAsStringSync();
      expect(content, contains('custom_lint'));
      expect(content, contains('build/**'), reason: 'the existing analyzer keys must survive');
    });

    test('appends to an existing plugins list rather than replacing it', () {
      options.writeAsStringSync('analyzer:\n  plugins:\n    - other_lint\n');

      expect(ensureCustomLintPlugin(options), isTrue);
      final content = options.readAsStringSync();
      expect(content, contains('custom_lint'));
      expect(content, contains('other_lint'), reason: 'another plugin must not be dropped');
    });
  });
}
