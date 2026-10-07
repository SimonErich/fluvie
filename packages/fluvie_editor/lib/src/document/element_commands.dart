part of 'editor_command.dart';

/// Moves or resizes an element: writes its `transform`.
final class SetTransformCommand extends EditorCommand {
  /// Sets [id]'s transform to [transform].
  const SetTransformCommand({required this.id, required this.transform});

  /// The element being placed.
  final String id;

  /// The new `transform` JSON (canvas fractions).
  final Map<String, Object?> transform;

  @override
  EditorDocument apply(EditorDocument document) => document.setTransform(id, transform);

  @override
  String get label => 'Move $id';

  @override
  Set<String> get affectedIds => {id};

  @override
  String get mergeKey => 'transform:$id';
}
