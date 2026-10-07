import 'dart:io';

import 'workspace_inventory.dart';

/// Reads only repository source, ignoring generated and dependency directories.
WorkspaceInventory loadWorkspaceInventory(Directory repository) {
  final root = repository.absolute;
  final manifests = <String, String>{};
  final files = <String>[];
  void scan(Directory directory) {
    for (final entity in directory.listSync(followLinks: false)) {
      final relative = entity.path.substring(root.path.length + 1).replaceAll(r'\', '/');
      if (entity is Directory) {
        final name = relative.split('/').last;
        if (name.startsWith('.') ||
            const {'build', 'node_modules', 'coverage', 'doc'}.contains(name)) {
          continue;
        }
        scan(entity);
      } else if (entity is File) {
        if (relative.endsWith('/pubspec.yaml')) {
          manifests[relative.substring(0, relative.length - '/pubspec.yaml'.length)] = entity
              .readAsStringSync();
        } else if (relative.endsWith('.dart')) {
          files.add(relative);
        }
      }
    }
  }

  scan(root);
  return WorkspaceInventory.parse(
    File('${root.path}/pubspec.yaml').readAsStringSync(),
    manifests: manifests,
    files: files,
  );
}
