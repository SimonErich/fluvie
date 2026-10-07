/// One declared workspace package and its applicable quality targets.
final class WorkspaceTarget {
  /// Creates immutable facts collected from the manifest and source inventory.
  const WorkspaceTarget({
    required this.path,
    required this.name,
    required this.flutter,
    required this.publishable,
    required this.hasSources,
    required this.hasTests,
  });

  final String path;
  final String name;
  final bool flutter;
  final bool publishable;
  final bool hasSources;
  final bool hasTests;

  /// Production libraries and apps are covered; examples are analyzed/tested.
  bool get production => RegExp(r'^(packages|apps)/[^/]+$').hasMatch(path);

  Map<String, Object?> toJson() => {
    'path': path,
    'name': name,
    'runtime': flutter ? 'flutter' : 'dart',
    'publishable': publishable,
    'production': production,
    'analyze': true,
    'test': hasTests,
    'coverage': production && hasSources,
  };
}
