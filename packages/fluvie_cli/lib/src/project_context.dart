import 'dart:io';

import 'package:yaml/yaml.dart';

/// What `fluvie init` found in a directory: whether it is a Flutter project, its
/// package name, and whether it already depends on `fluvie`.
final class ProjectContext {
  /// Creates a context describing [directory].
  const ProjectContext({
    required this.directory,
    required this.isFlutterProject,
    required this.packageName,
    required this.hasFluvieDependency,
  });

  /// The inspected directory.
  final Directory directory;

  /// Whether `pubspec.yaml` exists and declares a `flutter` dependency.
  final bool isFlutterProject;

  /// The package `name` from `pubspec.yaml`, or `null` when there is no pubspec.
  final String? packageName;

  /// Whether `dependencies` already lists `fluvie`.
  final bool hasFluvieDependency;
}

/// Inspects [directory] (default: the current directory) for a Flutter project.
///
/// A Flutter project is a `pubspec.yaml` whose `dependencies` include `flutter`.
ProjectContext detectProjectContext([Directory? directory]) {
  final dir = directory ?? Directory.current;
  final pubspec = File('${dir.path}/pubspec.yaml');
  if (!pubspec.existsSync()) {
    return ProjectContext(
      directory: dir,
      isFlutterProject: false,
      packageName: null,
      hasFluvieDependency: false,
    );
  }
  final doc = loadYaml(pubspec.readAsStringSync());
  final deps = doc is YamlMap ? doc['dependencies'] : null;
  final hasFlutter = deps is YamlMap && deps.containsKey('flutter');
  final hasFluvie = deps is YamlMap && deps.containsKey('fluvie');
  return ProjectContext(
    directory: dir,
    isFlutterProject: hasFlutter,
    packageName: doc is YamlMap ? doc['name'] as String? : null,
    hasFluvieDependency: hasFluvie,
  );
}
