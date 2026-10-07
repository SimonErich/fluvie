part of 'editor_command.dart';

/// Adds an element to a scene. The caller mints [id] up front (through
/// `EditorDocument.nextId`), so undo and redo always see the same element.
final class InsertElementCommand extends EditorCommand {
  /// Inserts [element] into scene [scene] as [id] (appended, or at [at]).
  const InsertElementCommand({
    required this.scene,
    required this.element,
    required this.id,
    this.at,
  });

  /// The scene receiving the element.
  final int scene;

  /// The element JSON (its `id` key is overridden by [id]).
  final Map<String, Object?> element;

  /// The new element's identity.
  final String id;

  /// The z-position, or null to append.
  final int? at;

  @override
  EditorDocument apply(EditorDocument document) =>
      document.insertElement(scene, {...element, 'id': id}, at: at).$1;

  @override
  String get label => 'Insert element';

  @override
  Set<String> get affectedIds => {id};
}
