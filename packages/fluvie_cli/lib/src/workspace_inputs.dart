import 'dart:convert';
import 'dart:io';

import 'package:fluvie_cli/src/preview_session.dart';
import 'package:fluvie_cli/src/project_resources.dart';
import 'package:path/path.dart' as p;

/// Metadata watcher over the source project and resolved dependency libraries.
/// Content hashes are computed only when these inputs change. Build/tool outputs
/// are ignored; package configuration and dependency manifest changes count.
String workspaceInputs(String project) {
  final records = <String>[sourceFingerprint(project)];
  var ancestor = p.absolute(project);
  while (true) {
    final config = File(p.join(ancestor, '.dart_tool', 'package_config.json'));
    if (config.existsSync()) {
      records.add(config.readAsStringSync());
      final doc = jsonDecode(records.last) as Map<String, Object?>;
      for (final entry in (doc['packages']! as List).cast<Map<String, Object?>>()) {
        final uri = config.uri.resolve(entry['rootUri']! as String);
        if (uri.scheme != 'file') continue;
        final root = uri.toFilePath();
        for (final directory in {'lib', 'assets', ...projectResources(root)}) {
          if (Directory(p.join(root, directory)).existsSync()) {
            records.add('$root/$directory:${sourceFingerprint(p.join(root, directory))}');
          } else if (File(p.join(root, directory)).existsSync()) {
            final file = File(p.join(root, directory));
            final stat = file.statSync();
            records.add('${file.path}:${stat.size}:${stat.modified.microsecondsSinceEpoch}');
          }
        }
        final pubspec = File(p.join(root, 'pubspec.yaml'));
        if (pubspec.existsSync()) {
          final stat = pubspec.statSync();
          records.add('${pubspec.path}:${stat.size}:${stat.modified.microsecondsSinceEpoch}');
        }
      }
      break;
    }
    final parent = p.dirname(ancestor);
    if (parent == ancestor) break;
    ancestor = parent;
  }
  return records.join('\n');
}
