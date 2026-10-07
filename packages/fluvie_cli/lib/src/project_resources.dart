import 'dart:io';

import 'package:path/path.dart' as p;
import 'package:yaml/yaml.dart';

/// Declared Flutter assets, shaders and font files, relative to a package root.
/// Resources belonging to another package are resolved through that package.
Iterable<String> projectResources(String root) sync* {
  final file = File(p.join(root, 'pubspec.yaml'));
  if (!file.existsSync()) return;
  final spec = loadYaml(file.readAsStringSync());
  if (spec is! YamlMap || spec['flutter'] is! YamlMap) return;
  final flutter = spec['flutter'] as YamlMap;
  for (final entry in [
    ...?(flutter['assets'] as YamlList?),
    ...?(flutter['shaders'] as YamlList?),
  ]) {
    final path = entry is String
        ? entry
        : entry is YamlMap
        ? entry['path']
        : null;
    if (path is String && !path.startsWith('packages/')) yield path;
  }
  for (final family in (flutter['fonts'] as YamlList?) ?? const []) {
    if (family is! YamlMap) continue;
    for (final font in (family['fonts'] as YamlList?) ?? const []) {
      if (font is YamlMap && font['asset'] is String) yield font['asset'] as String;
    }
  }
}
