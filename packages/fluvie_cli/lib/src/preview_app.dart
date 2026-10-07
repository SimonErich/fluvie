import 'dart:convert';
import 'dart:io';

import 'package:crypto/crypto.dart';
import 'package:fluvie_cli/src/cli_failure.dart';
import 'package:fluvie_cli/src/file_target.dart';
import 'package:fluvie_cli/src/init_support.dart' show localFluvieOverrides;
import 'package:fluvie_cli/src/process_runner.dart';
import 'package:fluvie_cli/src/templates/preview_app_template.dart';
import 'package:path/path.dart' as p;
import 'package:yaml/yaml.dart';
import 'package:yaml_edit/yaml_edit.dart';

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
typedef PreviewStamp = ({
  String projectDir,
  String target,
  String entry,
  String cliVersion,
  String inputs,
});

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
    inputs: _inputDigest(target.projectDir),
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
      localMediaBridge: true,
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

String _previewImport(FileTarget target) => target.externalImport;

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
      decoded['cliVersion'] == stamp.cliVersion &&
      decoded['inputs'] == stamp.inputs;
}

void _writeStamp(String dir, PreviewStamp stamp) =>
    File(p.join(dir, '.fluvie_preview_stamp.json')).writeAsStringSync(
      jsonEncode({
        'projectDir': stamp.projectDir,
        'target': stamp.target,
        'entry': stamp.entry,
        'cliVersion': stamp.cliVersion,
        'inputs': stamp.inputs,
      }),
    );

/// The source lock graph supplies exact package roots to the cached host solver.
/// Only preview-specific adapters are added; consumer libraries keep one identity.
void _writePreviewPubspec({required String dir, required FileTarget target}) {
  final name = packageNameOf(target.projectDir);
  if (name == null) throw CliFailure('The project at "${target.projectDir}" has no package name.');
  final source = _yamlMap(File(p.join(target.projectDir, 'pubspec.yaml')));
  final resolved = _resolvedPackages(target.projectDir);
  final overrides = <String, Object?>{};
  // Explicit root declarations also cover unresolved projects and git/hosted forms.
  for (final root in _overrideSources(target.projectDir)) {
    for (final filename in ['pubspec.yaml', 'pubspec_overrides.yaml']) {
      final doc = _yamlMap(File(p.join(root, filename)));
      final values = doc['dependency_overrides'];
      if (values is! Map) continue;
      for (final entry in values.entries) {
        final declaration = _plain(entry.value);
        if (declaration is Map<String, Object?> && declaration['path'] is String) {
          declaration['path'] = p.normalize(p.join(root, declaration['path']! as String));
        }
        overrides[entry.key.toString()] = declaration;
      }
    }
  }
  final declared = (source['dependencies'] as Map?)?['fluvie'];
  final overridden = overrides['fluvie'];
  final localDeclaration = overridden is Map
      ? overridden
      : declared is Map
      ? declared
      : null;
  final localPath = localDeclaration?['path'];
  final fluvieRoot =
      resolved['fluvie'] ??
      (localPath is String &&
              File(p.join(target.projectDir, localPath, 'pubspec.yaml')).existsSync()
          ? p.normalize(p.join(target.projectDir, localPath))
          : null);
  if (fluvieRoot != null) overrides.putIfAbsent('fluvie', () => {'path': fluvieRoot});
  if (fluvieRoot != null) {
    for (final entry in localFluvieOverrides(fluvieRoot).entries) {
      overrides.putIfAbsent(entry.key, () => {'path': entry.value});
    }
  }
  final webSibling = fluvieRoot == null
      ? null
      : p.join(p.dirname(fluvieRoot), 'fluvie_web_encoder');
  final hasWebSibling = webSibling != null && File(p.join(webSibling, 'pubspec.yaml')).existsSync();
  if (hasWebSibling) overrides.putIfAbsent('fluvie_web_encoder', () => {'path': webSibling});
  // A resolved consumer graph is authoritative over declarations and host solving.
  for (final entry in resolved.entries) {
    if (entry.key == name || _sdkPackages.contains(entry.key)) continue;
    overrides[entry.key] = {'path': entry.value};
  }
  final flutter = Map<String, Object?>.from((source['flutter'] as Map?) ?? {});
  flutter['uses-material-design'] = true;
  final assetEntries = <Object?>[
    ...?flutter['assets'] as List?,
    ..._assetEntriesFor(target.projectDir),
  ];
  if (assetEntries.isNotEmpty) flutter['assets'] = assetEntries.toSet().toList();
  final fluvieVersion = fluvieRoot == null
      ? '^0.3.1'
      : _yamlMap(File(p.join(fluvieRoot, 'pubspec.yaml')))['version'].toString();
  final editor = YamlEditor('')
    ..update([], {
      'name': 'fluvie_preview',
      'description': 'Package-owned live Fluvie preview host.',
      'publish_to': 'none',
      'version': '1.0.0',
      'environment': {'sdk': '^3.12.0'},
      'dependencies': {
        'flutter': {'sdk': 'flutter'},
        name: {'path': p.absolute(target.projectDir)},
        'fluvie': fluvieVersion,
        'fluvie_web_encoder': fluvieVersion,
        'http': '^1.2.0',
      },
      if (overrides.isNotEmpty) 'dependency_overrides': overrides,
      'flutter': flutter,
    });
  File(p.join(dir, 'pubspec.yaml')).writeAsStringSync(editor.toString());
}

const _sdkPackages = {
  'flutter',
  'flutter_test',
  'flutter_driver',
  'flutter_web_plugins',
  'flutter_localizations',
  'flutter_goldens',
  'sky_engine',
};

Map<String, Object?> _yamlMap(File file) {
  if (!file.existsSync()) return {};
  final value = _plain(loadYaml(file.readAsStringSync()));
  return value is Map<String, Object?> ? value : {};
}

Object? _plain(Object? value) => switch (value) {
  final Map<Object?, Object?> map => <String, Object?>{
    for (final entry in map.entries) entry.key.toString(): _plain(entry.value),
  },
  final List<Object?> list => list.map(_plain).toList(),
  _ => value,
};

Map<String, String> _resolvedPackages(String projectDir) {
  for (final dir in _ancestors(projectDir)) {
    final file = File(p.join(dir, '.dart_tool', 'package_config.json'));
    if (!file.existsSync()) continue;
    final doc = jsonDecode(file.readAsStringSync()) as Map<String, dynamic>;
    return {
      for (final entry in (doc['packages'] as List).cast<Map<String, dynamic>>())
        entry['name'] as String: file.uri.resolve(entry['rootUri'] as String).toFilePath(),
    };
  }
  return {};
}

Iterable<String> _ancestors(String projectDir) sync* {
  var dir = p.absolute(projectDir);
  while (true) {
    yield dir;
    final parent = p.dirname(dir);
    if (parent == dir) return;
    dir = parent;
  }
}

String _inputDigest(String projectDir) {
  final buffer = StringBuffer();
  for (final dir in _overrideSources(projectDir)) {
    for (final name in [
      'pubspec.yaml',
      'pubspec_overrides.yaml',
      '.dart_tool/package_config.json',
    ]) {
      final file = File(p.join(dir, name));
      if (file.existsSync()) buffer.write(file.readAsStringSync());
    }
  }
  return sha256.convert(utf8.encode(buffer.toString())).toString();
}

/// Least specific workspace roots first; source overrides then take precedence.
List<String> _overrideSources(String projectDir) {
  final sources = <String>[];
  for (final dir in _ancestors(projectDir)) {
    if (dir == p.absolute(projectDir) ||
        _yamlMap(File(p.join(dir, 'pubspec.yaml'))).containsKey('workspace')) {
      sources.add(dir);
    }
  }
  return sources.reversed.toList();
}

/// Symlinks the project's asset directories into the app root and returns the
/// pubspec entries for them.
void _linkAssets({required String dir, required String projectDir}) {
  final source = _yamlMap(File(p.join(projectDir, 'pubspec.yaml')));
  final flutter = source['flutter'] as Map?;
  final paths = <String>{if (Directory(p.join(projectDir, 'assets')).existsSync()) 'assets'};
  for (final entry in (flutter?['assets'] as List?) ?? const []) {
    final path = entry is String
        ? entry
        : entry is Map
        ? entry['path']
        : null;
    if (path is String && !path.startsWith('packages/')) paths.add(path);
  }
  for (final family in (flutter?['fonts'] as List?) ?? const []) {
    if (family is! Map) continue;
    for (final font in (family['fonts'] as List?) ?? const []) {
      if (font is Map && font['asset'] is String) paths.add(font['asset'] as String);
    }
  }
  final linked = <String>[];
  for (final logical in paths.toList()..sort((a, b) => a.length.compareTo(b.length))) {
    final sourcePath = p.normalize(p.join(projectDir, logical));
    final dest = p.normalize(p.join(dir, logical));
    if (!p.isWithin(dir, dest)) {
      throw CliFailure('Preview assets must use paths inside the project: "$logical".');
    }
    if (linked.any((path) => sourcePath == path || p.isWithin(path, sourcePath))) continue;
    final type = FileSystemEntity.typeSync(sourcePath);
    if (type == FileSystemEntityType.notFound) continue;
    Directory(p.dirname(dest)).createSync(recursive: true);
    try {
      Link(dest).createSync(p.absolute(sourcePath));
    } on FileSystemException {
      if (type == FileSystemEntityType.directory) {
        _copyDirectory(Directory(sourcePath), Directory(dest));
      } else {
        File(sourcePath).copySync(dest);
      }
    }
    linked.add(sourcePath);
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
