import 'dart:convert';
import 'dart:io';

import 'package:crypto/crypto.dart';
import 'package:fluvie_cli/src/cli_failure.dart';
import 'package:fluvie_cli/src/file_target.dart';
import 'package:fluvie_cli/src/process_runner.dart';
import 'package:fluvie_cli/src/templates/preview_app_template.dart';
import 'package:path/path.dart' as p;
import 'package:yaml/yaml.dart';

/// The preview app's cache root: `$XDG_CACHE_HOME/fluvie/preview` (POSIX) or
/// `%LOCALAPPDATA%\fluvie\preview` (Windows), mirroring the ffmpeg cache.
///
/// It lives outside the user's project deliberately. A preview app nested inside
/// the project would be a second pubspec under the same directory tree, which
/// breaks resolution when the project sits in a pub workspace — and Fluvie's own
/// repo is a workspace, so that path would fail for every contributor.
String previewCacheRoot({Map<String, String>? environment}) {
  final env = environment ?? Platform.environment;
  if (Platform.isWindows) {
    final local = env['LOCALAPPDATA'];
    if (local != null && local.isNotEmpty) return p.join(local, 'fluvie', 'preview');
  }
  final xdg = env['XDG_CACHE_HOME'];
  if (xdg != null && xdg.isNotEmpty) return p.join(xdg, 'fluvie', 'preview');
  final home = env['HOME'] ?? '';
  return p.join(home, '.cache', 'fluvie', 'preview');
}

/// The preview app directory for [projectDir], keyed by its absolute path so two
/// projects never share one app.
String previewAppDir(String projectDir, {Map<String, String>? environment}) {
  final digest = sha1.convert(utf8.encode(p.absolute(projectDir))).toString().substring(0, 16);
  return p.join(previewCacheRoot(environment: environment), digest);
}

/// What the scaffolded app was built for, so a stale one is rebuilt rather than
/// silently reused.
typedef PreviewStamp = ({String projectDir, String target, String entry, String cliVersion});

/// Scaffolds (or reuses) the preview app for [target] and returns its directory.
///
/// The app is a real Flutter app because `flutter run` is hard-gated on the
/// platform directory existing, with no bypass. It is created once per project
/// and stamped; a stamp miss deletes and recreates it, because `flutter create`
/// is not idempotent over an existing tree.
///
/// The app path-depends on the user's project, so pub resolves `fluvie` against
/// the user's own constraint and hot reload tracks the composition by its
/// resolved path. Assets are symlinked rather than declared with a `../` path:
/// Flutter follows symlinks when it bundles, while a `../` asset entry is
/// accepted and then silently written outside the bundle.
Future<String> ensurePreviewApp({
  required ProcessRunner runner,
  required FileTarget target,
  required List<String> platforms,
  required String cliVersion,
  required StringSink out,
  Map<String, String>? environment,
}) async {
  final dir = previewAppDir(target.projectDir, environment: environment);
  final stamp = (
    projectDir: p.absolute(target.projectDir),
    target: target.path,
    entry: target.entry,
    cliVersion: cliVersion,
  );
  if (_stampMatches(dir, stamp) && _hasPlatforms(dir, platforms)) return dir;

  out.writeln('Preparing the preview app (first run for this project)...');
  final appDir = Directory(dir);
  if (appDir.existsSync()) appDir.deleteSync(recursive: true);
  appDir.createSync(recursive: true);

  final created = await runner.run('flutter', [
    'create',
    '--project-name',
    'fluvie_preview',
    '--platforms',
    platforms.join(','),
    '.',
  ], workingDirectory: dir);
  if (created.exitCode != 0) {
    throw CliFailure(
      'Could not scaffold the preview app in "$dir".\n${created.stderr}',
    );
  }

  _writePreviewPubspec(dir: dir, target: target);
  _linkAssets(dir: dir, projectDir: target.projectDir);
  File(p.join(dir, 'lib', 'main.dart')).writeAsStringSync(
    previewAppSource(
      importLine: "import '${_previewImport(target)}' as target;",
      functionName: 'target.${target.entry}',
      title: p.basenameWithoutExtension(target.path),
    ),
  );
  // The counter test flutter create leaves behind names a widget the preview app
  // does not have, so it would fail a plain `flutter test` in the cache dir.
  final counterTest = File(p.join(dir, 'test', 'widget_test.dart'));
  if (counterTest.existsSync()) counterTest.deleteSync();

  final got = await runner.run('flutter', ['pub', 'get'], workingDirectory: dir);
  if (got.exitCode != 0) {
    throw CliFailure('Could not resolve the preview app dependencies.\n${got.stderr}');
  }
  _writeStamp(dir, stamp);
  return dir;
}

/// The import the preview app's `main.dart` reaches [target] by.
///
/// It must be a `package:` URI. The app lives outside the project, and a
/// relative import cannot escape a package: the compiler resolves it inside the
/// app's own `lib/`, so a `../..` climb to another tree fails to read. A render
/// has no such constraint because its harness is staged inside the project.
String _previewImport(FileTarget target) {
  final uri = target.packageUri;
  if (uri != null) return uri;
  throw CliFailure(
    'A previewed composition must live under lib/, and '
    '"${p.relative(target.path, from: target.projectDir)}" does not.\n'
    'The preview app runs outside your project and can only import your '
    'composition through its package URI, which only a file under lib/ has.\n'
    'Move it to lib/ and run: fluvie preview '
    './lib/${p.basename(target.path)}',
  );
}

bool _hasPlatforms(String dir, List<String> platforms) => platforms.every(
  (platform) => Directory(p.join(dir, platform == 'web' ? 'web' : platform)).existsSync(),
);

bool _stampMatches(String dir, PreviewStamp stamp) {
  final file = File(p.join(dir, '.fluvie_preview_stamp.json'));
  if (!file.existsSync()) return false;
  final decoded = jsonDecode(file.readAsStringSync());
  if (decoded is! Map<String, Object?>) return false;
  return decoded['projectDir'] == stamp.projectDir &&
      decoded['target'] == stamp.target &&
      decoded['entry'] == stamp.entry &&
      decoded['cliVersion'] == stamp.cliVersion;
}

void _writeStamp(String dir, PreviewStamp stamp) =>
    File(p.join(dir, '.fluvie_preview_stamp.json')).writeAsStringSync(
      jsonEncode({
        'projectDir': stamp.projectDir,
        'target': stamp.target,
        'entry': stamp.entry,
        'cliVersion': stamp.cliVersion,
      }),
    );

/// Writes the preview app's pubspec: a path dependency on the user's project
/// plus a copy of its dependency overrides.
///
/// The overrides matter: pub applies `dependency_overrides` only from the root
/// package of a resolution, so without copying them a contributor who
/// path-overrides `fluvie` would preview against the published package while
/// their renders use the local one — the same composition, different pixels.
void _writePreviewPubspec({required String dir, required FileTarget target}) {
  final name = packageNameOf(target.projectDir);
  if (name == null) {
    throw CliFailure(
      'The project at "${target.projectDir}" has no package name in its '
      'pubspec.yaml, so the preview app cannot depend on it.',
    );
  }
  final overrides = _resolvedOverrides(target.projectDir);
  final buffer = StringBuffer('''
name: fluvie_preview
description: The generated Fluvie preview app. Do not edit; it is regenerated.
publish_to: none
version: 1.0.0

environment:
  sdk: ^3.12.0

dependencies:
  flutter:
    sdk: flutter
  $name:
    path: ${p.absolute(target.projectDir)}

dev_dependencies:
  flutter_test:
    sdk: flutter

flutter:
  uses-material-design: true
  assets:
''');
  for (final entry in _assetEntriesFor(target.projectDir)) {
    buffer.writeln('    - $entry');
  }
  if (overrides.isNotEmpty) {
    buffer
      ..writeln('\ndependency_overrides:')
      ..write(overrides);
  }
  File(p.join(dir, 'pubspec.yaml')).writeAsStringSync(buffer.toString());
}

/// The user's `dependency_overrides`, re-emitted with every relative path made
/// absolute, or empty when there are none.
///
/// Both the project's own pubspec and its `pubspec_overrides.yaml` are read, and
/// so is the workspace root's when the project is a workspace member, because
/// pub requires a workspace's overrides to live at the root.
String _resolvedOverrides(String projectDir) {
  final buffer = StringBuffer();
  for (final dir in _overrideSources(projectDir)) {
    for (final file in ['pubspec_overrides.yaml', 'pubspec.yaml']) {
      final path = File(p.join(dir, file));
      if (!path.existsSync()) continue;
      final doc = loadYaml(path.readAsStringSync());
      if (doc is! YamlMap) continue;
      final overrides = doc['dependency_overrides'];
      if (overrides is! YamlMap) continue;
      overrides.forEach((key, value) {
        if (value is YamlMap && value['path'] != null) {
          final resolved = p.normalize(p.join(dir, '${value['path']}'));
          buffer.writeln('  $key:\n    path: $resolved');
        } else if (value is String) {
          buffer.writeln('  $key: $value');
        }
      });
    }
  }
  return buffer.toString();
}

/// The project directory plus any ancestor that declares a pub `workspace:`.
List<String> _overrideSources(String projectDir) {
  final sources = <String>[p.absolute(projectDir)];
  var dir = p.dirname(p.absolute(projectDir));
  while (true) {
    final pubspec = File(p.join(dir, 'pubspec.yaml'));
    if (pubspec.existsSync()) {
      final doc = loadYaml(pubspec.readAsStringSync());
      if (doc is YamlMap && doc['workspace'] != null) sources.add(dir);
    }
    final parent = p.dirname(dir);
    if (parent == dir) return sources;
    dir = parent;
  }
}

/// Symlinks the project's asset directories into the app root and returns the
/// pubspec entries for them.
void _linkAssets({required String dir, required String projectDir}) {
  final source = Directory(p.join(projectDir, 'assets'));
  if (!source.existsSync()) return;
  final link = Link(p.join(dir, 'assets'));
  if (link.existsSync()) link.deleteSync();
  try {
    link.createSync(p.absolute(source.path));
  } on FileSystemException {
    // Windows needs Developer Mode or elevation for a symlink; a copy bundles
    // the same bytes, it just goes stale until the next scaffold.
    _copyDirectory(source, Directory(p.join(dir, 'assets')));
  }
}

void _copyDirectory(Directory from, Directory to) {
  to.createSync(recursive: true);
  for (final entity in from.listSync(recursive: true)) {
    if (entity is! File) continue;
    final target = File(p.join(to.path, p.relative(entity.path, from: from.path)));
    target.parent.createSync(recursive: true);
    entity.copySync(target.path);
  }
}

/// The asset directory entries for the app's pubspec, mirroring the project's.
List<String> _assetEntriesFor(String projectDir) {
  final root = Directory(p.join(projectDir, 'assets'));
  if (!root.existsSync()) return const [];
  final dirs = <String>{'assets/'};
  for (final entity in root.listSync(recursive: true, followLinks: false)) {
    if (entity is! File) continue;
    final relative = p.url.joinAll(
      p.split(p.relative(p.dirname(entity.path), from: projectDir)),
    );
    dirs.add('$relative/');
  }
  final sorted = dirs.toList()..sort();
  return sorted;
}
