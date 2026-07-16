import 'dart:io';

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
