part of 'editor_command.dart';

/// Adds a whole batch of elements to a scene in one undo step — the paste
/// and duplicate payload. The caller mints every id up front (through
/// `EditorDocument.nextIds` and the re-mint pass), so undo and redo always
/// see the same elements.
final class InsertElementsCommand extends EditorCommand {
  /// Appends [elements] (each carrying its final `id`) to scene [scene], in
  /// order — or, with [group], to that group's children (the entered-group
  /// paste; a block target re-balances once per batch). A pasted Group never
  /// nests: with [group] set it lands at the scene's top level beside the
  /// entered group, so a mixed batch splits in one step (each side keeps its
  /// z-order). [verb] names the step for the undo menu.
  const InsertElementsCommand({
    required this.scene,
    required this.elements,
    this.verb = 'Paste',
    this.group,
  });

  /// The scene receiving the elements.
  final int scene;

  /// The element JSON batch, ids included, in z-order.
  final List<Map<String, Object?>> elements;

  /// What the undo menu calls this ("Paste", "Duplicate").
  final String verb;

  /// The group receiving the batch, or null for the scene's top level.
  final String? group;

  @override
  EditorDocument apply(EditorDocument document) {
    final target = group;
    if (target == null) {
      return elements.fold(
        document,
        (current, element) => current.insertElement(scene, element).$1,
      );
    }
    // One concept, everywhere: no element nests a group by an editor gesture
    // (move and drag forbid it too). With a group entered, a pasted Group
    // lands at the scene's top level beside it; everything else lands inside.
    // A mixed batch splits in one undo step, each side keeping its z-order.
    var next = document;
    for (final element in elements) {
      next = element['type'] == 'Group'
          ? next.insertElement(scene, element).$1
          : next.insertElementInGroup(target, element).$1;
    }
    return next.reflowBlock(target);
  }

  @override
  String get label => elements.length == 1 ? '$verb element' : '$verb ${elements.length} elements';

  @override
  Set<String> get affectedIds => {
    for (final element in elements)
      if (element['id'] case final String id) id,
  };
}

/// Deletes a whole selection in one undo step — the multi-delete the
/// clipboard epic owed the Delete key and the Cut command.
final class RemoveElementsCommand extends EditorCommand {
  /// Removes every element of [ids] (top-level or nested).
  const RemoveElementsCommand({required this.ids});

  /// The elements being removed.
  final List<String> ids;

  @override
  EditorDocument apply(EditorDocument document) =>
      ids.fold(document, (current, id) => current.removeElement(id));

  @override
  String get label => ids.length == 1 ? 'Delete ${ids.single}' : 'Delete ${ids.length} elements';

  @override
  Set<String> get affectedIds => ids.toSet();
}
