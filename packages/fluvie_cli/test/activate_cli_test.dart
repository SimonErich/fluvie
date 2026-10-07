import 'dart:convert';
import 'dart:io';

import 'package:path/path.dart' as p;
import 'package:test/test.dart';
import 'package:yaml/yaml.dart';

import '../../../tool/activate_cli.dart' as installer;

void main() {
  test('source install separates runtime resolution from workspace and dev dependencies', () {
    final fixture = Directory.systemTemp.createTempSync('fluvie_source_install_');
    addTearDown(() => fixture.deleteSync(recursive: true));
    final source = Directory(p.join(fixture.path, 'source'))..createSync();
    void package(String name, String text) {
      final root = Directory(p.join(source.path, 'packages', name))..createSync(recursive: true);
      File(p.join(root.path, 'pubspec.yaml')).writeAsStringSync('name: $name\n$text');
      Directory(p.join(root.path, 'lib')).createSync();
    }

    package(
      'fluvie_cli',
      'version: 0.3.1\nresolution: workspace\nexecutables:\n  fluvie:\n'
          'dependencies:\n  fluvie_media: any\n  fluvie_validate: any\n'
          'dev_dependencies:\n  editor: any\n',
    );
    Directory(p.join(source.path, 'packages/fluvie_cli/bin')).createSync();
    File(
      p.join(source.path, 'packages/fluvie_cli/lib/source.dart'),
    ).writeAsStringSync('const version = 1;');
    package('fluvie_media', 'version: 0.3.1\n');
    package('fluvie_validate', 'dependencies:\n  fluvie_lints: any\n');
    package('fluvie_lints', 'version: 0.3.1\n');
    package('editor', 'dependencies:\n  flutter:\n    sdk: flutter\n');

    final host = installer.prepareSourceCli(
      source,
      installDir: Directory(p.join(fixture.path, 'host')),
    );
    final manifest =
        loadYaml(File(p.join(host.path, 'pubspec.yaml')).readAsStringSync()) as YamlMap;
    final overrides =
        loadYaml(File(p.join(host.path, 'pubspec_overrides.yaml')).readAsStringSync()) as YamlMap;

    expect(manifest.containsKey('resolution'), isFalse);
    expect(manifest.containsKey('dev_dependencies'), isFalse);
    expect((manifest['executables']! as YamlMap)['fluvie'], isNull);
    expect(
      (overrides['dependency_overrides'] as YamlMap).keys,
      unorderedEquals([
        'fluvie_media',
        'fluvie_validate',
        'fluvie_lints',
      ]),
    );
    expect(File(p.join(host.path, 'lib/source.dart')).readAsStringSync(), 'const version = 1;');
    expect(
      (jsonDecode(File(p.join(host.path, 'fluvie-source.json')).readAsStringSync())
          as Map<String, Object?>)['sourceRoot'],
      source.path,
    );
    expect(
      File(p.join(source.path, 'packages/fluvie_cli/pubspec.yaml')).readAsStringSync(),
      contains('resolution: workspace'),
    );
    expect(installer.prepareSourceCli(source, installDir: host.parent).path, host.path);
  });

  test('source install rejects missing offline resolution and an in-workspace host', () {
    final fixture = Directory.systemTemp.createTempSync('fluvie_source_install_failure_');
    addTearDown(() => fixture.deleteSync(recursive: true));
    final cli = Directory(p.join(fixture.path, 'packages/fluvie_cli'))..createSync(recursive: true);
    File(p.join(cli.path, 'pubspec.yaml')).writeAsStringSync('name: fluvie_cli\n');

    expect(() => installer.prepareSourceCli(fixture, requireResolved: true), throwsFormatException);
    expect(
      () => installer.prepareSourceCli(
        fixture,
        installDir: Directory(p.join(fixture.path, 'nested')),
      ),
      throwsFormatException,
    );
  });
}
