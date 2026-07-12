import 'dart:io';

import 'package:fluvie_cli/src/init_new_project.dart' show packageNameFor;
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

  group('namesFor', () {
    test('default starter name', () {
      expect(namesFor('starter'), (
        key: 'starter',
        functionName: 'starterVideo',
        fileName: 'starter.dart',
      ));
    });

    test('multi-word name becomes snake key and camel function', () {
      expect(namesFor('Intro Clip'), (
        key: 'intro_clip',
        functionName: 'introClipVideo',
        fileName: 'intro_clip.dart',
      ));
    });

    test('a leading digit is prefixed so the identifier is valid', () {
      final names = namesFor('123 go');
      expect(names.functionName, 'v123GoVideo');
      expect(names.key, '123_go');
    });

    test('an empty name falls back to starter', () {
      expect(namesFor('  '), (
        key: 'starter',
        functionName: 'starterVideo',
        fileName: 'starter.dart',
      ));
    });
  });

  group('packageNameFor', () {
    test('passes through a valid name', () {
      expect(packageNameFor('my_fluvie_video'), 'my_fluvie_video');
    });

    test('sanitizes punctuation and case', () {
      expect(packageNameFor('My-Cool.App'), 'my_cool_app');
    });

    test('prefixes a leading digit', () {
      expect(packageNameFor('123app'), 'app_123app');
    });

    test('uses the last path segment', () {
      expect(packageNameFor('/tmp/some/cool_clip'), 'cool_clip');
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

  group('ensureDependency', () {
    late File pubspec;
    setUp(() {
      final dir = Directory.systemTemp.createTempSync('fluvie_pub_');
      addTearDown(() => dir.deleteSync(recursive: true));
      pubspec = File('${dir.path}/pubspec.yaml')
        ..writeAsStringSync('''
name: demo
dependencies:
  flutter:
    sdk: flutter
dev_dependencies:
  flutter_test:
    sdk: flutter
''');
    });

    test('adds a missing dependency and reports it', () {
      expect(
        ensureDependency(pubspec, section: 'dependencies', name: 'fluvie', version: '^0.1.0'),
        isTrue,
      );
      expect(pubspec.readAsStringSync(), contains('fluvie: ^0.1.0'));
    });

    test('is a no-op when already present', () {
      ensureDependency(pubspec, section: 'dependencies', name: 'fluvie', version: '^0.1.0');
      expect(
        ensureDependency(pubspec, section: 'dependencies', name: 'fluvie', version: '^0.2.0'),
        isFalse,
      );
      expect(pubspec.readAsStringSync(), contains('fluvie: ^0.1.0'));
      expect(pubspec.readAsStringSync(), isNot(contains('^0.2.0')));
    });

    test('adds a dev dependency', () {
      expect(
        ensureDependency(
          pubspec,
          section: 'dev_dependencies',
          name: 'alchemist',
          version: '^0.14.0',
        ),
        isTrue,
      );
      expect(pubspec.readAsStringSync(), contains('alchemist: ^0.14.0'));
    });

    test('creates the section when it does not exist', () {
      final dir = Directory.systemTemp.createTempSync('fluvie_pub_nosection_');
      addTearDown(() => dir.deleteSync(recursive: true));
      final minimal = File('${dir.path}/pubspec.yaml')..writeAsStringSync('name: demo\n');

      expect(
        ensureDependency(minimal, section: 'dependencies', name: 'fluvie', version: '^0.1.0'),
        isTrue,
      );
      expect(minimal.readAsStringSync(), contains('fluvie: ^0.1.0'));
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
  });
}
