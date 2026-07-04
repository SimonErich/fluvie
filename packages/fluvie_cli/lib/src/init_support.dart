import 'dart:io';

import 'package:fluvie_cli/src/templates/capture_harness_template.dart';
import 'package:fluvie_cli/src/templates/widget_test_template.dart';
import 'package:yaml/yaml.dart';
import 'package:yaml_edit/yaml_edit.dart';

/// The pinned `fluvie` dependency `fluvie init` adds to a project.
const String fluvieDependencyVersion = '^0.1.0';

/// The pinned `alchemist` dev dependency the render harness needs (it loads the
/// real bundled fonts so captured text is not Ahem boxes).
const String alchemistDependencyVersion = '^0.14.0';

/// The pinned `fluvie_lints` dev dependency `fluvie init` wires up: the rules
/// that catch timing mistakes (dangling anchors, cyclic triggers, animations
/// past their window) as you type.
const String fluvieLintsDependencyVersion = '^0.1.0';

/// The pinned `custom_lint` dev dependency that hosts the fluvie_lints rules
/// in the analyzer.
const String customLintDependencyVersion = '^0.8.0';

/// The names `fluvie init` derives from a composition name: the render `key`,
/// the Dart builder `functionName`, and the `fileName` under `lib/`.
typedef ScaffoldNames = ({String key, String functionName, String fileName});

/// Derives the [ScaffoldNames] for a composition [name].
///
/// `"Intro Clip"` becomes key `intro_clip`, function `introClipVideo`, file
/// `intro_clip.dart`. A leading digit is prefixed so the identifier is valid.
ScaffoldNames namesFor(String name) {
  final words = name
      .split(RegExp('[^A-Za-z0-9]+'))
      .where((w) => w.isNotEmpty)
      .toList(growable: false);
  final safe = words.isEmpty ? ['starter'] : words;
  final key = safe.map((w) => w.toLowerCase()).join('_');
  final camel = safe.first.toLowerCase() + safe.skip(1).map(_capitalize).join();
  final base = RegExp('^[0-9]').hasMatch(camel) ? 'v$camel' : camel;
  return (key: key, functionName: '${base}Video', fileName: '$key.dart');
}

String _capitalize(String word) =>
    word.isEmpty ? word : word[0].toUpperCase() + word.substring(1).toLowerCase();

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

/// Ensures [pubspec] lists [name] under [section] (`dependencies` or
/// `dev_dependencies`) at [version]; a no-op when it is already present.
///
/// Returns `true` when the dependency was added.
bool ensureDependency(
  File pubspec, {
  required String section,
  required String name,
  required String version,
}) {
  final content = pubspec.readAsStringSync();
  final doc = loadYaml(content);
  final existing = doc is YamlMap ? doc[section] : null;
  if (existing is YamlMap && existing.containsKey(name)) return false;
  final editor = YamlEditor(content);
  if (existing is YamlMap) {
    editor.update([section, name], version);
  } else {
    editor.update([section], {name: version});
  }
  pubspec.writeAsStringSync(editor.toString());
  return true;
}

/// Writes the render harness and a widget test for [names] into [projectDir],
/// registering [packageName]'s `lib/`-relative [libPath], and adds the
/// `alchemist` dev dependency the harness needs.
///
/// Returns the project-relative paths written (skipping any that already existed
/// when [force] is `false`).
List<String> writeRenderScaffold({
  required Directory projectDir,
  required String packageName,
  required ScaffoldNames names,
  required String libPath,
  required bool force,
}) {
  final written = <String>[];
  final harness = File('${projectDir.path}/test/render/capture_harness_test.dart');
  final harnessWritten = writeFileIfAbsent(
    harness,
    captureHarnessSource(
      packageName: packageName,
      compositions: [(key: names.key, function: names.functionName, libPath: libPath)],
    ),
    force: force,
  );
  if (harnessWritten) written.add('test/render/capture_harness_test.dart');

  final test = File('${projectDir.path}/test/${names.key}_test.dart');
  final testWritten = writeFileIfAbsent(
    test,
    widgetTestSource(
      importLine: "import 'package:$packageName/$libPath';",
      functionName: names.functionName,
    ),
    force: force,
  );
  if (testWritten) written.add('test/${names.key}_test.dart');

  ensureDependency(
    File('${projectDir.path}/pubspec.yaml'),
    section: 'dev_dependencies',
    name: 'alchemist',
    version: alchemistDependencyVersion,
  );
  // Fluvie's own lints ride the same scaffold: the rules that catch timing
  // mistakes (dangling anchors, cyclic triggers) light up in the IDE without
  // any manual wiring.
  ensureDependency(
    File('${projectDir.path}/pubspec.yaml'),
    section: 'dev_dependencies',
    name: 'custom_lint',
    version: customLintDependencyVersion,
  );
  ensureDependency(
    File('${projectDir.path}/pubspec.yaml'),
    section: 'dev_dependencies',
    name: 'fluvie_lints',
    version: fluvieLintsDependencyVersion,
  );
  final lintsWired = ensureCustomLintPlugin(File('${projectDir.path}/analysis_options.yaml'));
  if (lintsWired) written.add('analysis_options.yaml');
  return written;
}

/// Wires the `custom_lint` analyzer plugin into [analysisOptions] so the
/// fluvie_lints rules run in the IDE and via `dart run custom_lint`.
///
/// Creates the file (on the `flutter_lints` base `flutter create` would write)
/// when absent; otherwise appends the `analyzer: plugins:` block, preserving
/// the existing content. Idempotent: returns `false` when the plugin is
/// already wired.
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
