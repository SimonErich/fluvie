part of 'editor_command.dart';

/// Wraps a selection into a new Group element — members keep their ids and
/// their pixels; only their frame of reference changes.
final class GroupElementsCommand extends EditorCommand {
  /// Groups the top-level elements [ids] of scene [scene] into [groupId]
  /// (minted up front via `EditorDocument.nextId`), placed at [transform]
  /// (the members' bounding box, canvas fractions).
  const GroupElementsCommand({
    required this.scene,
    required this.ids,
    required this.groupId,
    required this.transform,
  });

  /// The scene whose elements group.
  final int scene;

  /// The member ids, in z-order.
  final List<String> ids;

  /// The new group's identity.
  final String groupId;

  /// The group's `transform` JSON (the members' bounding box).
  final Map<String, Object?> transform;

  @override
  EditorDocument apply(EditorDocument document) =>
      document.groupElements(scene, ids, groupId: groupId, groupTransform: transform);

  @override
  String get label => 'Group ${ids.length} elements';

  @override
  Set<String> get affectedIds => {groupId, ...ids};
}

/// Dissolves groups back into their members — the inverse of
/// [GroupElementsCommand], ids stable both ways.
final class UngroupElementsCommand extends EditorCommand {
  /// Ungroups every group in [ids] in one undo step.
  const UngroupElementsCommand({required this.ids});

  /// The group ids being dissolved.
  final List<String> ids;

  @override
  EditorDocument apply(EditorDocument document) =>
      ids.fold(document, (current, id) => current.ungroupElement(id));

  @override
  String get label => 'Ungroup';

  @override
  Set<String> get affectedIds => ids.toSet();
}

/// Moves a selection through the z-order: forward, backward, to the front,
/// or to the back — relative order preserved (the Figma semantics).
final class ArrangeOrderCommand extends EditorCommand {
  /// Applies [order] to [ids] (each holding list rearranges independently).
  const ArrangeOrderCommand({required this.ids, required this.order});

  /// The moved element ids.
  final List<String> ids;

  /// Which z-order move to apply.
  final ArrangeOrder order;

  @override
  EditorDocument apply(EditorDocument document) => document.arrangeOrder(ids, order);

  @override
  String get label => switch (order) {
    ArrangeOrder.forward => 'Bring forward',
    ArrangeOrder.backward => 'Send backward',
    ArrangeOrder.front => 'Bring to front',
    ArrangeOrder.back => 'Send to back',
  };

  @override
  Set<String> get affectedIds => ids.toSet();
}

/// Hides or shows elements through the spec's `visible` flag — one undo
/// step, render-affecting (the digest moves), unlike the editor-block lock.
final class SetElementsVisibleCommand extends EditorCommand {
  /// Sets `visible` to [visible] on every element of [ids].
  const SetElementsVisibleCommand({required this.ids, required this.visible});

  /// The elements being hidden or shown.
  final List<String> ids;

  /// The new visibility.
  final bool visible;

  @override
  EditorDocument apply(EditorDocument document) =>
      ids.fold(document, (current, id) => current.setElementVisible(id, visible: visible));

  @override
  String get label {
    final verb = visible ? 'Show' : 'Hide';
    return ids.length == 1 ? '$verb ${ids.single}' : '$verb ${ids.length} elements';
  }

  @override
  Set<String> get affectedIds => ids.toSet();
}

/// Writes editor-block metadata for a whole selection in one undo step —
/// the multi-selection lock (never render-affecting).
final class SetElementsMetaCommand extends EditorCommand {
  /// Merges [meta] into every element of [ids].
  const SetElementsMetaCommand({required this.ids, required this.meta});

  /// The elements being annotated.
  final List<String> ids;

  /// The metadata to merge into each one.
  final Map<String, Object?> meta;

  @override
  EditorDocument apply(EditorDocument document) =>
      ids.fold(document, (current, id) => current.setElementMeta(id, meta));

  @override
  String get label =>
      ids.length == 1 ? 'Annotate ${ids.single}' : 'Annotate ${ids.length} elements';

  @override
  Set<String> get affectedIds => ids.toSet();
}
