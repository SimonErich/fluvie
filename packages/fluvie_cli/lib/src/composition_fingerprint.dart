import 'dart:convert';
import 'dart:io';

import 'package:crypto/crypto.dart';
import 'package:fluvie_cli/src/project_resources.dart';
import 'package:path/path.dart' as p;

/// Exact local inputs used to invalidate frame caches and explain a render.
final class CompositionFingerprint {
  /// Creates a stable aggregate and its independently hashed input records.
  const CompositionFingerprint(this.digest, this.files, {this.sdk = const {}});
  final String digest;
  final Map<String, Object?> sdk;
  final List<Map<String, Object?>> files;
  Map<String, Object?> toJson() => {'files': files};
}

/// Hashes authored/transitive Dart, dependency manifests, and resource bytes.
/// Project-local Dart outside `lib/` is included conservatively; generated
/// source directories and build/tool caches are excluded from that scan.
/// Runtime network/generator resources require `--no-cache` when their bytes
/// are not materialized as declared local assets before invocation.
Future<CompositionFingerprint> fingerprintComposition(
  String projectDir, {
  Map<String, Object?> context = const {},
  Iterable<String> extraFiles = const [],
  Iterable<String> excludedSourceDirectories = const [],
}) async {
  final inputs = <String, String>{};
  final sdk = <String, Object?>{
    'cliDartVersion': Platform.version,
    'cliDartExecutable': Platform.resolvedExecutable,
  };
  final root = p.absolute(projectDir);
  final excludedSources = [
    for (final directory in excludedSourceDirectories) p.normalize(p.absolute(directory)),
  ];
  void add(String path, String label) {
    final absolute = p.normalize(p.absolute(path));
    if (File(absolute).existsSync()) inputs.putIfAbsent(absolute, () => label);
  }

  void tree(String path, String label, {bool dartOnly = false, bool authoredOnly = false}) {
    final seen = <String>{};
    void walk(String current, String logical) {
      if (authoredOnly &&
          (FileSystemEntity.isLinkSync(current) ||
              excludedSources.any((dir) => p.equals(dir, current) || p.isWithin(dir, current)))) {
        return;
      }
      final type = FileSystemEntity.typeSync(current);
      if (type == FileSystemEntityType.file) {
        if (!dartOnly || current.endsWith('.dart')) add(current, logical);
      } else if (type == FileSystemEntityType.directory) {
        final directory = Directory(current);
        if (!seen.add(directory.resolveSymbolicLinksSync())) return;
        for (final entity in directory.listSync(followLinks: false)) {
          final name = p.basename(entity.path);
          if (dartOnly && {'.dart_tool', '.git', 'build', 'node_modules'}.contains(name)) continue;
          walk(entity.path, '$logical/$name');
        }
      }
    }

    walk(path, label);
  }

  void package(String packageRoot, String label) {
    final pubspec = File(p.join(packageRoot, 'pubspec.yaml'));
    add(pubspec.path, '$label/pubspec.yaml');
    tree(p.join(packageRoot, 'lib'), '$label/lib', dartOnly: true);
    for (final path in projectResources(packageRoot)) {
      tree(p.join(packageRoot, path), '$label/$path');
    }
  }

  package(root, 'project');
  // A target outside lib may import or include authored Dart anywhere in the
  // source project. Hash that source conservatively rather than approximating
  // Dart's conditional imports, exports, and parts with a text parser.
  tree(root, 'project', dartOnly: true, authoredOnly: true);
  tree(p.join(root, 'assets'), 'project/assets');
  for (final name in ['pubspec.lock', 'pubspec_overrides.yaml']) {
    add(p.join(root, name), 'project/$name');
  }
  var ancestor = root;
  while (true) {
    final config = File(p.join(ancestor, '.dart_tool', 'package_config.json'));
    if (config.existsSync()) {
      add(config.path, 'resolution/package_config.json');
      add(p.join(ancestor, 'pubspec.lock'), 'resolution/pubspec.lock');
      add(p.join(ancestor, 'pubspec.yaml'), 'resolution/pubspec.yaml');
      final json = jsonDecode(config.readAsStringSync()) as Map<String, Object?>;
      for (final entry in (json['packages']! as List).cast<Map<String, Object?>>()) {
        final uri = config.uri.resolve(entry['rootUri']! as String);
        if (uri.scheme == 'file') {
          package(uri.toFilePath(), 'package:${entry['name']}');
          if (entry['name'] == 'flutter') {
            final flutterRoot = p.dirname(
              p.dirname(uri.toFilePath().replaceFirst(RegExp(r'[/\\]$'), '')),
            );
            final version = File(p.join(flutterRoot, 'bin/cache/flutter.version.json'));
            sdk['flutterExecutable'] = p.join(
              flutterRoot,
              'bin',
              Platform.isWindows ? 'flutter.bat' : 'flutter',
            );
            if (version.existsSync()) {
              sdk['flutter'] = jsonDecode(version.readAsStringSync());
              add(version.path, 'sdk/flutter.version.json');
            }
          }
        }
      }
      break;
    }
    final parent = p.dirname(ancestor);
    if (parent == ancestor) break;
    ancestor = parent;
  }
  for (final path in extraFiles) {
    add(path, 'input:${p.absolute(path)}');
  }
  final entries = inputs.entries.toList()..sort((a, b) => a.value.compareTo(b.value));
  final records = <Map<String, Object?>>[];
  for (var start = 0; start < entries.length; start += 8) {
    final end = (start + 8).clamp(0, entries.length);
    records.addAll(
      await Future.wait(
        entries.sublist(start, end).map((entry) async {
          final file = File(entry.key);
          final digest = await sha256.bind(file.openRead()).first;
          return {
            'path': entry.value,
            'byteLength': await file.length(),
            'sha256': digest.toString(),
          };
        }),
      ),
    );
  }
  return CompositionFingerprint(
    sha256
        .convert(
          utf8.encode(
            jsonEncode({'schemaVersion': 1, 'context': context, 'sdk': sdk, 'files': records}),
          ),
        )
        .toString(),
    List.unmodifiable(records),
    sdk: Map.unmodifiable(sdk),
  );
}
