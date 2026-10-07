import 'dart:convert';
import 'dart:io';

import 'package:path/path.dart' as p;
import 'package:yaml/yaml.dart';

/// The nearest pubspec directory, or `null` outside a Dart/Flutter project.
String? findPubspecDirectory(String from) {
  var dir = p.normalize(p.absolute(from));
  if (FileSystemEntity.isFileSync(dir)) dir = p.dirname(dir);
  while (true) {
    if (File(p.join(dir, 'pubspec.yaml')).existsSync()) return dir;
    final parent = p.dirname(dir);
    if (parent == dir) return null;
    dir = parent;
  }
}

/// Finds the resolved package configuration, including a workspace ancestor.
File? findPackageConfiguration(String projectDir) {
  var dir = p.normalize(p.absolute(projectDir));
  while (true) {
    final file = File(p.join(dir, '.dart_tool', 'package_config.json'));
    if (file.existsSync()) return file;
    final parent = p.dirname(dir);
    if (parent == dir) return null;
    dir = parent;
  }
}

/// Reads the names actually resolved for a project; never runs pub or writes.
Set<String> resolvedPackageNames(File? configuration) {
  if (configuration == null) return const {};
  final config = jsonDecode(configuration.readAsStringSync()) as Map<String, Object?>;
  return {
    for (final entry in (config['packages'] as List<Object?>? ?? []))
      if (entry is Map<String, Object?> && entry['name'] is String) entry['name']! as String,
  };
}

/// A project's authored pubspec, with YAML types retained for nested entries.
YamlMap readProjectPubspec(String projectDir) {
  final data = loadYaml(File(p.join(projectDir, 'pubspec.yaml')).readAsStringSync());
  if (data is! YamlMap) throw const FormatException('The pubspec must be a YAML mapping.');
  return data;
}
