part of 'editor_command.dart';

/// Replaces an element's content wholesale (the inspector's big hammer).
final class ReplaceElementCommand extends EditorCommand {
  /// Replaces [id] with [element]. A non-null [mergeGroup] coalesces a
  /// stream of replacements (a slider drag) into one undo step.
  const ReplaceElementCommand({required this.id, required this.element, this.mergeGroup});

  /// The element being replaced.
  final String id;

  /// The new element JSON; the id is kept even when the patch omits it.
  final Map<String, Object?> element;

  /// The coalescing group, or null for a standalone step.
  final String? mergeGroup;

  @override
  EditorDocument apply(EditorDocument document) => document.editSharedContent(id, element);

  @override
  String get label => 'Edit $id';

  @override
  Set<String> get affectedIds => {id};

  @override
  String? get mergeKey => mergeGroup == null ? null : 'replace:$mergeGroup:$id';
}
