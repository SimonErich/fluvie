part of 'editor_command.dart';

/// Deletes an element.
final class RemoveElementCommand extends EditorCommand {
  /// Removes [id].
  const RemoveElementCommand({required this.id});

  /// The element being removed.
  final String id;

  @override
  EditorDocument apply(EditorDocument document) => document.removeElement(id);

  @override
  String get label => 'Delete $id';

  @override
  Set<String> get affectedIds => {id};
}
