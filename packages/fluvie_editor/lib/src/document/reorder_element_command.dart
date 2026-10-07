part of 'editor_command.dart';

/// Changes an element's z-order within its scene.
final class ReorderElementCommand extends EditorCommand {
  /// Moves [id] to z-position [to].
  const ReorderElementCommand({required this.id, required this.to});

  /// The element being reordered.
  final String id;

  /// The target z-position.
  final int to;

  @override
  EditorDocument apply(EditorDocument document) => document.reorderElement(id, to: to);

  @override
  String get label => 'Reorder $id';

  @override
  Set<String> get affectedIds => {id};
}
