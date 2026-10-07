// Run directly with `dart tool/activate_cli.dart`: no workspace resolution or
// Flutter SDK is required to install the pure Dart CLI from this checkout.
import 'dart:convert';
import 'dart:io';

Future<void> main(List<String> arguments) async {
  var prepareOnly = false;
  var offline = false;
  Directory? installDir;
  for (var index = 0; index < arguments.length; index++) {
    switch (arguments[index]) {
      case '--prepare-only':
        prepareOnly = true;
      case '--offline':
        offline = true;
      case '--install-dir':
        if (++index == arguments.length) {
          stderr.writeln('--install-dir needs an external directory.');
          exitCode = 64;
          return;
        }
        installDir = Directory(arguments[index]);
      case '--help' || '-h':
        stdout.writeln(
          'dart tool/activate_cli.dart [--prepare-only] [--install-dir PATH] [--offline]',
        );
        return;
      default:
        stderr.writeln('Unknown option: ${arguments[index]}');
        exitCode = 64;
        return;
    }
  }
  try {
    final source = File.fromUri(Platform.script).parent.parent;
    final host = prepareSourceCli(source, installDir: installDir, requireResolved: offline);
    stdout.writeln('Prepared standalone CLI at ${host.path}');
    if (prepareOnly) return;
    if (offline) {
      final result = await _dart(['pub', 'get', '--offline'], workingDirectory: host.path);
      if (result != 0) {
        exitCode = result;
        return;
      }
    }
    exitCode = await _dart(['pub', 'global', 'activate', '--source', 'path', host.path]);
    if (exitCode == 0) {
      stdout.writeln('Source changes remain linked. Run fluvie --help to get started.');
    }
  } on FileSystemException catch (error) {
    stderr.writeln(
      'Could not prepare the CLI: ${error.message} (${error.path ?? "source checkout"}).',
    );
    exitCode = 1;
  } on FormatException catch (error) {
    stderr.writeln(error.message);
    exitCode = 1;
  }
}

Future<int> _dart(List<String> args, {String? workingDirectory}) async => (await Process.start(
  Platform.resolvedExecutable,
  args,
  workingDirectory: workingDirectory,
  mode: ProcessStartMode.inheritStdio,
)).exitCode;

/// Creates an external package containing only the CLI's runtime dependency
/// graph. Existing resolved package roots are pinned when available, and local
/// Fluvie packages always come from [sourceDirectory]. No consumer project is modified.
Directory prepareSourceCli(
  Directory sourceDirectory, {
  Directory? installDir,
  Map<String, String>? environment,
  bool requireResolved = false,
}) {
  final source = Directory(sourceDirectory.resolveSymbolicLinksSync());
  final cli = Directory.fromUri(source.uri.resolve('packages/fluvie_cli/'));
  final manifest = File.fromUri(cli.uri.resolve('pubspec.yaml')).readAsStringSync();
  final local = <String, Directory>{};
  for (final entry in Directory.fromUri(source.uri.resolve('packages/')).listSync()) {
    if (entry is! Directory) continue;
    final pubspec = File.fromUri(entry.uri.resolve('pubspec.yaml'));
    if (!pubspec.existsSync()) continue;
    final name = RegExp(
      r'^name:\s*([a-z][a-z0-9_]*)\s*$',
      multiLine: true,
    ).firstMatch(pubspec.readAsStringSync())?.group(1);
    if (name != null) local[name] = entry;
  }
  final resolved = _resolvedRuntimeRoots(source, _dependencies(manifest));
  if (requireResolved && resolved == null) {
    throw const FormatException(
      '--offline needs an existing resolved package config and runtime graph. '
      'Resolve the checkout once, or omit --offline to fetch only CLI dependencies.',
    );
  }
  final overrides = <String, String>{...?resolved};
  final visited = <String>{};
  final pending = _dependencies(manifest).toList();
  while (pending.isNotEmpty) {
    final name = pending.removeLast();
    if (!visited.add(name)) continue;
    final package = local[name];
    if (package == null) continue;
    final text = File.fromUri(package.uri.resolve('pubspec.yaml')).readAsStringSync();
    if (RegExp(r'^\s+sdk:\s*flutter\s*$', multiLine: true).hasMatch(_dependencyBlock(text))) {
      throw FormatException(
        'CLI runtime package "$name" requires Flutter; keep source activation pure Dart.',
      );
    }
    overrides[name] = package.resolveSymbolicLinksSync();
    pending.addAll(_dependencies(text));
  }
  final base =
      installDir?.absolute ??
      _defaultInstallDirectory(source.path, environment ?? Platform.environment);
  if (base.path == source.path || base.path.startsWith('${source.path}${Platform.pathSeparator}')) {
    throw const FormatException('--install-dir must be outside the source workspace.');
  }
  final host = Directory.fromUri(base.uri.resolve('fluvie_cli/'))..createSync(recursive: true);
  final marker = File.fromUri(host.uri.resolve('fluvie-source.json'));
  if (File.fromUri(host.uri.resolve('pubspec.yaml')).existsSync() && !marker.existsSync()) {
    throw FormatException(
      'Refusing to replace an existing package at ${host.path}; choose another --install-dir.',
    );
  }
  if (marker.existsSync()) {
    final previous = jsonDecode(marker.readAsStringSync()) as Map<String, Object?>;
    if (previous['sourceRoot'] != source.path) {
      throw FormatException(
        'The install directory belongs to another checkout: ${previous['sourceRoot']}.',
      );
    }
  }
  marker.writeAsStringSync(jsonEncode({'schemaVersion': 1, 'sourceRoot': source.path}));
  File.fromUri(host.uri.resolve('pubspec.yaml')).writeAsStringSync(_runtimeManifest(manifest));
  final sorted = overrides.keys.toList()..sort();
  File.fromUri(host.uri.resolve('pubspec_overrides.yaml')).writeAsStringSync(
    const JsonEncoder.withIndent('  ').convert({
      'dependency_overrides': {
        for (final name in sorted) name: {'path': overrides[name]},
      },
    }),
  );
  for (final directory in ['lib', 'bin']) {
    _linkOrCopy(Directory.fromUri(cli.uri.resolve('$directory/')), host.uri.resolve(directory));
  }
  return host;
}

Directory _defaultInstallDirectory(String sourcePath, Map<String, String> environment) {
  final cache =
      environment['XDG_CACHE_HOME'] ??
      (Platform.isWindows ? environment['LOCALAPPDATA'] : null) ??
      (environment['HOME'] == null ? Directory.systemTemp.path : '${environment['HOME']}/.cache');
  var digest = 0x811c9dc5;
  for (final byte in utf8.encode(sourcePath)) {
    digest = ((digest ^ byte) * 0x01000193) & 0xffffffff;
  }
  return Directory('$cache/fluvie/cli/${digest.toRadixString(16)}');
}

Map<String, String>? _resolvedRuntimeRoots(Directory source, Iterable<String> dependencies) {
  final configFile = File.fromUri(source.uri.resolve('.dart_tool/package_config.json'));
  final graphFile = File.fromUri(source.uri.resolve('.dart_tool/package_graph.json'));
  if (!configFile.existsSync() || !graphFile.existsSync()) return null;
  final config = jsonDecode(configFile.readAsStringSync()) as Map<String, Object?>;
  final graph = jsonDecode(graphFile.readAsStringSync()) as Map<String, Object?>;
  final packages = {
    for (final value in (config['packages']! as List).cast<Map<String, Object?>>())
      value['name']! as String: value,
  };
  final nodes = {
    for (final value in (graph['packages']! as List).cast<Map<String, Object?>>())
      value['name']! as String: value,
  };
  final roots = <String, String>{};
  final pending = dependencies.toList();
  while (pending.isNotEmpty) {
    final name = pending.removeLast();
    if (roots.containsKey(name)) continue;
    if (name == 'flutter' || name == 'flutter_test') {
      throw const FormatException(
        'The resolved CLI runtime requires Flutter; keep its dependency graph pure Dart.',
      );
    }
    final package = packages[name];
    final node = nodes[name];
    if (package == null || node == null) return null;
    final uri = configFile.uri.resolve(package['rootUri']! as String);
    if (uri.scheme != 'file' || !Directory.fromUri(uri).existsSync()) return null;
    roots[name] = Directory.fromUri(uri).resolveSymbolicLinksSync();
    pending.addAll((node['dependencies']! as List).cast<String>());
  }
  return roots;
}

String _dependencyBlock(String text) {
  final lines = text.split('\n');
  final start = lines.indexWhere((line) => line == 'dependencies:');
  if (start < 0) return '';
  return lines.skip(start + 1).takeWhile((line) => !RegExp('^[a-zA-Z_]').hasMatch(line)).join('\n');
}

Iterable<String> _dependencies(String text) => RegExp(
  '^  ([a-z][a-z0-9_]*):',
  multiLine: true,
).allMatches(_dependencyBlock(text)).map((match) => match.group(1)!);

String _runtimeManifest(String text) {
  final kept = <String>[];
  var skip = false;
  for (final line in text.split('\n')) {
    if (RegExp('^[a-zA-Z_]').hasMatch(line)) {
      skip = line.startsWith('resolution:') || line.startsWith('dev_dependencies:');
    }
    if (!skip) kept.add(line);
  }
  return '${kept.join('\n').trimRight()}\n';
}

void _linkOrCopy(Directory source, Uri destination) {
  final target = Link.fromUri(destination);
  if (target.existsSync()) {
    if (target.resolveSymbolicLinksSync() == source.resolveSymbolicLinksSync()) return;
    target.deleteSync();
  }
  final copy = Directory.fromUri(destination);
  if (copy.existsSync()) copy.deleteSync(recursive: true);
  try {
    target.createSync(source.path);
  } on FileSystemException {
    copy.createSync(recursive: true);
    for (final entry in source.listSync(recursive: true)) {
      final relative = entry.path.substring(source.path.length + 1);
      final uri = copy.uri.resolve(relative.replaceAll(Platform.pathSeparator, '/'));
      if (entry is Directory) Directory.fromUri(uri).createSync(recursive: true);
      if (entry is File) {
        File.fromUri(uri).parent.createSync(recursive: true);
        entry.copySync(File.fromUri(uri).path);
      }
    }
  }
}
