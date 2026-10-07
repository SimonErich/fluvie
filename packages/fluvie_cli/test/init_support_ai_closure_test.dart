import 'dart:io';

import 'package:fluvie_cli/src/init_support.dart';
import 'package:test/test.dart';
import 'package:yaml/yaml.dart';

void main() {
  test('local AI initialization resolves its unpublished transitive package closure', () async {
    final root = await Directory.systemTemp.createTemp('fluvie_init_closure_');
    addTearDown(() => root.delete(recursive: true));
    for (final name in ['fluvie', 'fluvie_ai', 'fluvie_validate', 'fluvie_lints']) {
      final dependency = switch (name) {
        'fluvie_ai' => 'fluvie_validate',
        'fluvie_validate' => 'fluvie_lints',
        _ => null,
      };
      File('${root.path}/$name/pubspec.yaml')
        ..createSync(recursive: true)
        ..writeAsStringSync(
          'name: $name\n${dependency == null ? '' : 'dependencies:\n  $dependency: ^0.3.1\n'}',
        );
    }
    final spec = File('${root.path}/project/pubspec.yaml')
      ..createSync(recursive: true)
      ..writeAsStringSync('name: demo\n');
    expect(ensureFluvieDependencies(spec, fluviePath: '${root.path}/fluvie', withAi: true), isTrue);
    final parsed = loadYaml(spec.readAsStringSync()) as YamlMap;
    final overrides = parsed['dependency_overrides'] as YamlMap;
    expect((overrides['fluvie_validate'] as YamlMap)['path'], '${root.path}/fluvie_validate');
    expect((overrides['fluvie_lints'] as YamlMap)['path'], '${root.path}/fluvie_lints');
    expect(
      ensureFluvieDependencies(spec, fluviePath: '${root.path}/fluvie', withAi: true),
      isFalse,
    );
  });
}
