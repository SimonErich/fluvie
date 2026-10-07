import 'dart:io';

import 'package:fluvie_cli/src/cli_failure.dart';
import 'package:path/path.dart' as p;
import 'package:yaml/yaml.dart';
import 'package:yaml_edit/yaml_edit.dart';

/// The pinned `fluvie` dependency `fluvie init` adds to a project.
const String fluvieDependencyVersion = '^0.3.1';

/// The pinned `alchemist` dev dependency the generated capture harness needs (it
/// loads the real bundled fonts so captured text is not Ahem boxes).
const String alchemistDependencyVersion = '^0.14.0';

/// The pinned `fluvie_lints` dev dependency `fluvie init` wires up: the rules
/// that catch timing mistakes (dangling anchors, cyclic triggers, animations
/// past their window) as you type.
const String fluvieLintsDependencyVersion = '^0.3.1';

/// The pinned `custom_lint` dev dependency that hosts the fluvie_lints rules
/// in the analyzer.
const String customLintDependencyVersion = '^0.8.0';

/// Adds Fluvie's missing dependencies without replacing project configuration.
bool ensureFluvieDependencies(
  File pubspec, {
  String? fluviePath,
  bool withLints = false,
  bool withAi = false,
}) {
  final source = pubspec.readAsStringSync();
  final doc = loadYaml(source);
  if (doc is! YamlMap) throw const CliFailure('pubspec.yaml must contain a YAML mapping.');
  final editor = YamlEditor(source);
  var changed = false;
  final existingFluvie = [
    doc['dependency_overrides'],
    doc['dependencies'],
    doc['dev_dependencies'],
  ].whereType<YamlMap>().map((section) => section['fluvie']).whereType<YamlMap>().firstOrNull;
  final existingPath = existingFluvie?['path'];
  final local = fluviePath != null
      ? resolveFluviePath(fluviePath)
      : existingPath is String &&
            File(p.join(pubspec.parent.path, existingPath, 'pubspec.yaml')).existsSync()
      ? resolveFluviePath(p.join(pubspec.parent.path, existingPath))
      : null;
  final additions = <String, Map<String, Object?>>{
    'dependencies': {
      'fluvie': local == null ? fluvieDependencyVersion : {'path': local},
      if (withAi)
        'fluvie_ai':
            local != null &&
                File(p.join(p.dirname(local), 'fluvie_ai', 'pubspec.yaml')).existsSync()
            ? {'path': p.join(p.dirname(local), 'fluvie_ai')}
            : fluvieDependencyVersion,
    },
    'dev_dependencies': {
      if (withLints) 'flutter_lints': '^6.0.0',
      if (withLints) 'custom_lint': customLintDependencyVersion,
      if (withLints)
        'fluvie_lints':
            local != null &&
                File(p.join(p.dirname(local), 'fluvie_lints', 'pubspec.yaml')).existsSync()
            ? {'path': p.join(p.dirname(local), 'fluvie_lints')}
            : fluvieLintsDependencyVersion,
    },
  };
  for (final section in additions.entries) {
    final current = doc[section.key];
    if (current != null && current is! YamlMap) {
      throw CliFailure('${section.key} in pubspec.yaml must contain a YAML mapping.');
    }
    if (current == null) editor.update([section.key], <String, Object?>{});
    for (final dependency in section.value.entries) {
      final exists = ['dependencies', 'dev_dependencies', 'dependency_overrides'].any(
        (key) => doc[key] is YamlMap && (doc[key] as YamlMap).containsKey(dependency.key),
      );
      if (exists && !(dependency.key == 'fluvie' && local != null)) continue;
      final selectedSection =
          dependency.key == 'fluvie' &&
              local != null &&
              doc['dependency_overrides'] is YamlMap &&
              (doc['dependency_overrides'] as YamlMap).containsKey('fluvie')
          ? 'dependency_overrides'
          : section.key;
      final existingValue = (doc[selectedSection] as YamlMap?)?[dependency.key];
      if (dependency.value is Map<String, Object?> &&
          existingValue is YamlMap &&
          existingValue['path'] is String &&
          p.normalize(p.join(pubspec.parent.path, existingValue['path']! as String)) ==
              (dependency.value! as Map<String, Object?>)['path']) {
        continue;
      }
      editor.update([selectedSection, dependency.key], dependency.value);
      changed = true;
    }
  }
  if (local != null) {
    final overrides = doc['dependency_overrides'];
    var overridesPresent = overrides != null;
    final localOverrides = <String, String>{
      'fluvie': local,
      ...localFluvieOverrides(local),
      if (withAi && File(p.join(p.dirname(local), 'fluvie_ai/pubspec.yaml')).existsSync())
        ...localFluvieOverrides(p.join(p.dirname(local), 'fluvie_ai')),
      if (withAi && File(p.join(p.dirname(local), 'fluvie_ai/pubspec.yaml')).existsSync())
        'fluvie_ai': p.join(p.dirname(local), 'fluvie_ai'),
      if (withLints && File(p.join(p.dirname(local), 'fluvie_lints/pubspec.yaml')).existsSync())
        'fluvie_lints': p.join(p.dirname(local), 'fluvie_lints'),
    };
    for (final entry in localOverrides.entries) {
      if (overrides is YamlMap && overrides.containsKey(entry.key)) continue;
      if (!overridesPresent) {
        editor.update(['dependency_overrides'], <String, Object?>{});
        overridesPresent = true;
      }
      editor.update(['dependency_overrides', entry.key], {'path': entry.value});
      changed = true;
    }
  }
  if (changed) pubspec.writeAsStringSync(editor.toString());
  return changed;
}

/// Local transitive Fluvie packages needed by an unpublished checkout.
Map<String, String> localFluvieOverrides(String fluvieRoot) {
  final result = <String, String>{};
  final pending = <String>[fluvieRoot];
  final visited = <String>{};
  while (pending.isNotEmpty) {
    final root = pending.removeLast();
    if (!visited.add(root)) continue;
    final spec = loadYaml(File(p.join(root, 'pubspec.yaml')).readAsStringSync()) as YamlMap;
    final dependencies = spec['dependencies'];
    if (dependencies is! YamlMap) continue;
    for (final name in dependencies.keys.whereType<String>().where(
      (name) => name.startsWith('fluvie'),
    )) {
      final path = p.join(p.dirname(fluvieRoot), name);
      if (!File(p.join(path, 'pubspec.yaml')).existsSync()) continue;
      result[name] = path;
      pending.add(path);
    }
  }
  result.remove('fluvie');
  return result;
}

/// Adds build ignores while preserving an existing Flutter project's rules.
bool ensureProjectGitignore(File file, String defaults) {
  if (!file.existsSync()) {
    file.writeAsStringSync(defaults);
    return true;
  }
  final source = file.readAsStringSync();
  final lines = source.split('\n').map((line) => line.trim()).toSet();
  final missing = ['.dart_tool/', 'build/'].where((line) => !lines.contains(line)).toList();
  if (missing.isEmpty) return false;
  file.writeAsStringSync(
    '$source${source.endsWith('\n') ? '' : '\n'}\n# Fluvie build output.\n${missing.join('\n')}\n',
  );
  return true;
}

/// Accepts either the package directory or the local monorepo checkout.
String resolveFluviePath(String value) {
  final input = p.normalize(p.absolute(value));
  final nested = p.join(input, 'packages', 'fluvie');
  final selected = File(p.join(nested, 'pubspec.yaml')).existsSync() ? nested : input;
  final pubspec = File(p.join(selected, 'pubspec.yaml'));
  if (!pubspec.existsSync() ||
      (loadYaml(pubspec.readAsStringSync()) as YamlMap)['name'] != 'fluvie') {
    throw CliFailure('--fluvie-path must point to the fluvie package or its checkout: "$value".');
  }
  return selected;
}

/// The file-name slug `fluvie init` derives from a composition [name].
///
/// `"Intro Clip"` becomes `intro_clip`. An empty name falls back to
/// `example_video`, and a leading digit is prefixed, because the slug names a
/// library file that other Dart may import.
String compositionSlug(String name) {
  final words = name.split(RegExp('[^A-Za-z0-9]+')).where((w) => w.isNotEmpty);
  final slug = words.map((w) => w.toLowerCase()).join('_');
  if (slug.isEmpty) return 'example_video';
  return RegExp('^[0-9]').hasMatch(slug) ? 'v$slug' : slug;
}

/// Writes [content] to [file], creating parent directories.
///
/// Returns `true` when written; returns `false` (writing nothing) when [file]
/// already exists and [force] is `false`, so the caller can report a skip.
bool writeFileIfAbsent(File file, String content, {required bool force}) {
  if (file.existsSync() && !force) return false;
  file.parent.createSync(recursive: true);
  file.writeAsStringSync(content);
  return true;
}

/// Wires the `custom_lint` analyzer plugin into [analysisOptions] so the
/// fluvie_lints rules run in the IDE and via `dart run custom_lint`.
///
/// Creates the file (on the `flutter_lints` base) when absent; otherwise appends
/// the `analyzer: plugins:` block, preserving the existing content. Idempotent:
/// returns `false` when the plugin is already wired.
bool ensureCustomLintPlugin(File analysisOptions) {
  if (!analysisOptions.existsSync()) {
    analysisOptions
      ..createSync(recursive: true)
      ..writeAsStringSync(
        'include: package:flutter_lints/flutter.yaml\n'
        '\n'
        'analyzer:\n'
        '  plugins:\n'
        '    - custom_lint\n',
      );
    return true;
  }
  final content = analysisOptions.readAsStringSync();
  final doc = loadYaml(content);
  final analyzer = doc is YamlMap ? doc['analyzer'] : null;
  final plugins = analyzer is YamlMap ? analyzer['plugins'] : null;
  if (plugins is YamlList && plugins.contains('custom_lint')) return false;
  final editor = YamlEditor(content);
  if (analyzer is! YamlMap) {
    editor.update(
      ['analyzer'],
      {
        'plugins': ['custom_lint'],
      },
    );
  } else if (plugins is! YamlList) {
    editor.update(['analyzer', 'plugins'], ['custom_lint']);
  } else {
    editor.appendToList(['analyzer', 'plugins'], 'custom_lint');
  }
  analysisOptions.writeAsStringSync(editor.toString());
  return true;
}
