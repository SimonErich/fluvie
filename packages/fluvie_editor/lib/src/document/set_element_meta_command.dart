part of 'editor_command.dart';

/// Writes editor-block metadata (name, lock, and friends) for an element.
final class SetElementMetaCommand extends EditorCommand {
  /// Merges [meta] into [id]'s editor metadata.
  const SetElementMetaCommand({required this.id, required this.meta});

  /// The element being annotated.
  final String id;

  /// The metadata to merge.
  final Map<String, Object?> meta;

  @override
  EditorDocument apply(EditorDocument document) => document.setElementMeta(id, meta);

  @override
  String get label => 'Annotate $id';

  @override
  Set<String> get affectedIds => {id};

  @override
  String get mergeKey => 'meta:$id:${meta.keys.join(',')}';
}
