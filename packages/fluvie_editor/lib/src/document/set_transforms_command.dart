part of 'editor_command.dart';

/// Places a whole selection at once — the gizmo's commit on release, and
/// the arrow keys' nudge.
final class SetTransformsCommand extends EditorCommand {
  /// Writes every entry of [transforms] (id to `transform` JSON) in one
  /// undo step. A non-null [mergeGroup] coalesces consecutive runs over the
  /// same selection (a stream of nudges undoes as one).
  const SetTransformsCommand({required this.transforms, this.mergeGroup});

  /// The new `transform` JSON per element id.
  final Map<String, Map<String, Object?>> transforms;

  /// The coalescing group, or null for a standalone step.
  final String? mergeGroup;

  @override
  EditorDocument apply(EditorDocument document) => transforms.entries.fold(
    document,
    (current, entry) => current.setTransform(entry.key, entry.value),
  );

  @override
  String get label => transforms.length == 1
      ? 'Move ${transforms.keys.single}'
      : 'Move ${transforms.length} elements';

  @override
  Set<String> get affectedIds => transforms.keys.toSet();

  @override
  String? get mergeKey {
    final group = mergeGroup;
    if (group == null) return null;
    final ids = transforms.keys.toList()..sort();
    return 'transforms:$group:${ids.join('+')}';
  }
}
