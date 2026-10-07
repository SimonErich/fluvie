part of 'editor_command.dart';

/// Inserts a prepared title's elements and missing tokens/masters atomically.
final class InsertTitleCommand extends EditorCommand {
  /// [title] must already carry ids minted by TitleTemplate.prepare.
  const InsertTitleCommand({required this.scene, required this.title});

  /// The scene receiving the composition.
  final int scene;

  /// Prepared title data, including its additive dependencies.
  final Map<String, Object?> title;

  @override
  EditorDocument apply(EditorDocument document) {
    final rawMasters = document.toJson()['masters'];
    final masters = mergedMastersJson(
      rawMasters is Map<String, Object?> ? rawMasters : null,
      title['masters'] as Map<String, Object?>?,
    );
    final theme = mergedThemeJson(document.themeJson, title['theme'] as Map<String, Object?>?);
    var next = document.updateVideo({'theme': ?theme, 'masters': ?masters});
    for (final child in (title['children']! as List).cast<Map<String, Object?>>()) {
      next = next.insertElement(scene, child).$1;
    }
    return next;
  }

  @override
  String get label => 'Insert ${title['name']}';
  @override
  Set<String> get affectedIds => {
    for (final child in title['children']! as List) (child as Map)['id']! as String,
  };
}
