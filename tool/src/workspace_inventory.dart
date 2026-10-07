import 'package:yaml/yaml.dart';

import 'workspace_target.dart';

/// Source-derived package selections shared by all workspace quality gates.
final class WorkspaceInventory {
  WorkspaceInventory._(this.targets, this.problems);

  /// Parses source facts without filesystem or process access.
  factory WorkspaceInventory.parse(
    String rootPubspec, {
    required Map<String, String> manifests,
    required Iterable<String> files,
  }) {
    final root = _manifest(rootPubspec);
    final rawPaths = root['workspace'];
    if (rawPaths is! List<Object?>) {
      throw const FormatException('Root pubspec needs workspace paths');
    }
    final problems = <String>[];
    final paths = <String>{};
    for (final raw in rawPaths) {
      if (raw is! String || !_validPath(raw)) {
        problems.add(
          'Invalid workspace path "$raw": use a relative directory inside the repository.',
        );
        continue;
      }
      final path = raw
          .replaceAll(r'\', '/')
          .replaceFirst(RegExp(r'^\./'), '')
          .replaceFirst(RegExp(r'/$'), '');
      if (!paths.add(path)) problems.add('Duplicate workspace path: $path');
    }
    for (final path in manifests.keys.where((path) => !paths.contains(path))) {
      problems.add(
        '$path/pubspec.yaml is omitted from the root workspace; add the intended target.',
      );
    }
    final sourceFiles = files.map((file) => file.replaceAll(r'\', '/')).toList();
    final targets = <WorkspaceTarget>[];
    final names = <String, String>{};
    for (final path in paths.toList()..sort()) {
      final body = manifests[path];
      if (body == null) {
        problems.add('Declared workspace target $path has no pubspec.yaml.');
        continue;
      }
      final spec = _manifest(body);
      final name = spec['name'];
      if (name is! String || name.isEmpty) {
        problems.add('$path/pubspec.yaml needs a package name.');
        continue;
      }
      final owner = names[name];
      if (owner != null) problems.add('Duplicate package name "$name": $owner and $path.');
      names[name] = path;
      final target = WorkspaceTarget(
        path: path,
        name: name,
        flutter: _usesFlutter(spec),
        publishable: spec['publish_to'] != 'none',
        hasSources: sourceFiles.any(
          (file) => file.startsWith('$path/lib/') && file.endsWith('.dart'),
        ),
        hasTests: sourceFiles.any(
          (file) => file.startsWith('$path/test/') && file.endsWith('_test.dart'),
        ),
      );
      if (target.production && target.hasSources && !target.hasTests) {
        problems.add(
          '$name ($path) has production Dart sources but no test/*_test.dart coverage producer.',
        );
      }
      targets.add(target);
    }
    return WorkspaceInventory._(List.unmodifiable(targets), List.unmodifiable(problems));
  }

  final List<WorkspaceTarget> targets;
  final List<String> problems;

  List<String> get analysisPaths => targets.map((target) => target.path).toList();
  List<String> get testPaths =>
      targets.where((target) => target.hasTests).map((target) => target.path).toList();
  List<String> get coveragePaths => targets
      .where((target) => target.production && target.hasSources)
      .map((target) => target.path)
      .toList();
  List<String> get coverageFiles =>
      coveragePaths.map((path) => '$path/coverage/lcov.info').toList();

  /// Public API docs include production libraries, including private packages.
  List<String> get dartdocPaths => targets
      .where(
        (target) => target.production && target.path.startsWith('packages/') && target.hasSources,
      )
      .map((target) => target.path)
      .toList();
  List<String> get publishableNames =>
      targets.where((target) => target.publishable).map((target) => target.name).toList()..sort();

  Map<String, Object?> toJson() => {
    'schemaVersion': 1,
    'coveragePolicy':
        'Production packages/* and apps/* with Dart lib sources; examples analyzed and tested.',
    'dartdocPolicy':
        'Production packages/* with Dart lib sources, including private library packages; excludes apps/examples.',
    'targets': targets.map((target) => target.toJson()).toList(),
    'analysisPaths': analysisPaths,
    'testPaths': testPaths,
    'coveragePaths': coveragePaths,
    'coverageFiles': coverageFiles,
    'dartdocPaths': dartdocPaths,
    'publishableNames': publishableNames,
    'problems': problems,
  };
}

Map<Object?, Object?> _manifest(String body) {
  final value = loadYaml(body);
  if (value is! Map<Object?, Object?>) throw const FormatException('A pubspec must be a YAML map');
  return value;
}

bool _validPath(String path) =>
    path.isNotEmpty &&
    !RegExp(r'^[\\/]|^[a-zA-Z]:|[*?]').hasMatch(path) &&
    !path.replaceAll(r'\', '/').split('/').contains('..');

bool _usesFlutter(Map<Object?, Object?> spec) {
  for (final section in ['dependencies', 'dev_dependencies']) {
    final dependencies = spec[section];
    if (dependencies is Map<Object?, Object?> &&
        dependencies.values.any(
          (value) => value is Map<Object?, Object?> && value['sdk'] == 'flutter',
        )) {
      return true;
    }
  }
  return false;
}
