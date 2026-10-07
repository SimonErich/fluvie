import 'dart:convert';
import 'dart:io';

import 'package:crypto/crypto.dart';
import 'package:fluvie_cli/src/cli_failure.dart';
import 'package:fluvie_cli/src/init_support.dart' show localFluvieOverrides;
import 'package:fluvie_cli/src/process_runner.dart';
import 'package:path/path.dart' as p;
import 'package:pub_semver/pub_semver.dart';
import 'package:yaml/yaml.dart';

/// Selects the consumer configuration directly when it already has test support.
/// Only missing SDK support is resolved in a cache; consumer versions always win.
Future<String> prepareRenderPackageConfig({
  required String projectDir,
  required ProcessRunner runner,
  required String cacheRoot,
  bool author = false,
}) async {
  var config = _findConfig(projectDir);
  if (config == null) {
    final result = await runner.run('flutter', ['pub', 'get'], workingDirectory: projectDir);
    if (result.exitCode != 0) {
      throw CliFailure(
        'Could not resolve the project dependencies.\n${result.stdout}\n${result.stderr}',
      );
    }
    config = _findConfig(projectDir);
    if (config == null) {
      throw CliFailure('flutter pub get did not create a package configuration in "$projectDir".');
    }
  }
  final consumer = _readConfig(config);
  final packages = _byName(consumer);
  if (!packages.containsKey('fluvie')) {
    throw const CliFailure(
      'This project has no resolved fluvie dependency. Run `flutter pub add fluvie` or `fluvie init`, then `flutter pub get`.',
    );
  }
  if (packages.containsKey('flutter_test') && (!author || packages.containsKey('fluvie_ai'))) {
    return config.path;
  }
  final graphFile = File(p.join(config.parent.path, 'package_graph.json'));
  final workspacePubspec = File(p.join(config.parent.parent.path, 'pubspec.yaml'));
  final key = sha256
      .convert(
        utf8.encode(
          '${config.readAsStringSync()}|${graphFile.existsSync() ? graphFile.readAsStringSync() : ''}|${workspacePubspec.readAsStringSync()}|support-4|$author',
        ),
      )
      .toString();
  final dir = Directory(p.join(cacheRoot, 'support', key))..createSync(recursive: true);
  final lock = await File(p.join(dir.path, '.lock')).open(mode: FileMode.append);
  await lock.lock();
  try {
    final overlay = File(p.join(dir.path, 'overlay', '.dart_tool', 'package_config.json'));
    if (overlay.existsSync()) return overlay.path;
    final fluvieRoot = Uri.parse(packages['fluvie']!['rootUri']! as String).toFilePath();
    final dependencies = <String, Object?>{
      'flutter': {'sdk': 'flutter'},
      'flutter_test': {'sdk': 'flutter'},
      if (author) 'fluvie_ai': _aiDependency(fluvieRoot),
    };
    File(p.join(dir.path, 'pubspec.yaml')).writeAsStringSync(
      jsonEncode({
        'name': 'fluvie_render_support',
        'publish_to': 'none',
        'environment': {'sdk': '>=3.12.0 <4.0.0'},
        'dependencies': dependencies,
        'dependency_overrides': {
          'fluvie': {'path': fluvieRoot},
          for (final entry in {
            ...localFluvieOverrides(fluvieRoot),
            if (author &&
                File(p.join(p.dirname(fluvieRoot), 'fluvie_ai/pubspec.yaml')).existsSync())
              ...localFluvieOverrides(p.join(p.dirname(fluvieRoot), 'fluvie_ai')),
          }.entries)
            entry.key: {'path': entry.value},
          for (final entry in packages.entries.where((entry) => entry.key.startsWith('fluvie')))
            entry.key: {'path': Uri.parse(entry.value['rootUri']! as String).toFilePath()},
        },
      }),
    );
    final result = await runner.run('flutter', ['pub', 'get'], workingDirectory: dir.path);
    if (result.exitCode != 0) {
      throw CliFailure(
        'Could not prepare Flutter render support without changing the project.\n${result.stdout}\n${result.stderr}',
      );
    }
    final supportFile = File(p.join(dir.path, '.dart_tool', 'package_config.json'));
    if (!supportFile.existsSync()) {
      throw const CliFailure('Flutter render support did not produce a package configuration.');
    }
    final support = _readConfig(supportFile);
    final supportPackages = _byName(support);
    _validateCompatibility(packages, supportPackages);
    final merged = <String, Object?>{
      ...consumer,
      'packages': {...supportPackages, ...packages}.values.toList(),
    };
    overlay.parent.createSync(recursive: true);
    final consumerGraph = File(p.join(config.parent.path, 'package_graph.json'));
    final supportGraph = File(p.join(supportFile.parent.path, 'package_graph.json'));
    if (!consumerGraph.existsSync() || !supportGraph.existsSync()) {
      throw const CliFailure(
        'Missing dependency graph for native render support. Run `flutter pub get` in the source project.',
      );
    }
    _mergeGraphs(
      consumerGraph,
      supportGraph,
      File(p.join(overlay.parent.path, 'package_graph.json')),
      projectDir,
      author,
    );
    // Flutter locates workspace hook user_defines next to the package configuration.
    File(p.join(overlay.parent.parent.path, 'pubspec.yaml')).writeAsStringSync(
      File(p.join(config.parent.parent.path, 'pubspec.yaml')).readAsStringSync(),
    );
    overlay.writeAsStringSync(jsonEncode(merged));
    return overlay.path;
  } finally {
    await lock.unlock();
    await lock.close();
  }
}

File? _findConfig(String projectDir) {
  var dir = p.absolute(projectDir);
  while (true) {
    final file = File(p.join(dir, '.dart_tool', 'package_config.json'));
    if (file.existsSync()) return file;
    final parent = p.dirname(dir);
    if (parent == dir) return null;
    dir = parent;
  }
}

Map<String, Object?> _readConfig(File file) {
  final doc = jsonDecode(file.readAsStringSync()) as Map<String, Object?>;
  for (final entry in (doc['packages']! as List).cast<Map<String, Object?>>()) {
    entry['rootUri'] = file.uri.resolve(entry['rootUri']! as String).toString();
  }
  return doc;
}

Map<String, Map<String, Object?>> _byName(Map<String, Object?> config) => {
  for (final entry in (config['packages']! as List).cast<Map<String, Object?>>())
    entry['name']! as String: entry,
};

Object _aiDependency(String fluvieRoot) {
  final sibling = p.join(p.dirname(fluvieRoot), 'fluvie_ai');
  if (File(p.join(sibling, 'pubspec.yaml')).existsSync()) return {'path': sibling};
  final pubspec = loadYaml(File(p.join(fluvieRoot, 'pubspec.yaml')).readAsStringSync()) as YamlMap;
  return pubspec['version'] as String;
}

void _validateCompatibility(
  Map<String, Map<String, Object?>> consumer,
  Map<String, Map<String, Object?>> support,
) {
  for (final package in support.values) {
    final root = Uri.parse(package['rootUri']! as String).toFilePath();
    final pubspec = loadYaml(File(p.join(root, 'pubspec.yaml')).readAsStringSync()) as YamlMap;
    final dependencies = pubspec['dependencies'];
    if (dependencies is! YamlMap) continue;
    for (final dependency in dependencies.entries) {
      final selected = consumer[dependency.key];
      if (selected == null) continue;
      final declaration = dependency.value;
      final constraint = declaration is String
          ? declaration
          : declaration is YamlMap
          ? declaration['version']
          : null;
      if (constraint is! String || constraint == 'any') continue;
      final selectedRoot = Uri.parse(selected['rootUri']! as String).toFilePath();
      final selectedSpec =
          loadYaml(File(p.join(selectedRoot, 'pubspec.yaml')).readAsStringSync()) as YamlMap;
      final version = Version.parse((selectedSpec['version'] ?? '0.0.0').toString());
      if (!VersionConstraint.parse(constraint).allows(version)) {
        throw CliFailure(
          'Render support requires ${dependency.key} $constraint, but the project resolved $version. Add `flutter_test: {sdk: flutter}` to dev_dependencies and run `flutter pub get` to resolve this SDK constraint explicitly. The project lockfile was preserved.',
        );
      }
    }
  }
  final flutter = consumer['flutter'];
  if (flutter != null &&
      Uri.parse(
            flutter['rootUri']! as String,
          ).normalizePath().toFilePath().replaceFirst(RegExp(r'[/\\]$'), '') !=
          Uri.parse(
            support['flutter']!['rootUri']! as String,
          ).normalizePath().toFilePath().replaceFirst(RegExp(r'[/\\]$'), '')) {
    throw const CliFailure(
      'The project and render support resolve different Flutter SDKs. Run `flutter pub get` with the same Flutter executable used for rendering.',
    );
  }
}

void _mergeGraphs(
  File consumerFile,
  File supportFile,
  File output,
  String projectDir,
  bool author,
) {
  final consumer = jsonDecode(consumerFile.readAsStringSync()) as Map<String, Object?>;
  final support = jsonDecode(supportFile.readAsStringSync()) as Map<String, Object?>;
  final entries = <String, Map<String, Object?>>{
    for (final entry in (support['packages']! as List).cast<Map<String, Object?>>())
      entry['name']! as String: entry,
    for (final entry in (consumer['packages']! as List).cast<Map<String, Object?>>())
      entry['name']! as String: entry,
  };
  final name =
      (loadYaml(File(p.join(projectDir, 'pubspec.yaml')).readAsStringSync()) as YamlMap)['name'];
  final project = entries[name];
  if (project != null) {
    project['devDependencies'] = {
      ...?(project['devDependencies'] as List?),
      'flutter_test',
      if (author) 'fluvie_ai',
    }.toList();
  }
  output.writeAsStringSync(jsonEncode({...consumer, 'packages': entries.values.toList()}));
}
