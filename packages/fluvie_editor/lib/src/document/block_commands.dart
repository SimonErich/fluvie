part of 'editor_command.dart';

/// Wraps a selection into a new Group, tags it as a smart block, and runs
/// the first reflow — one undo step from freeform to arranged.
final class MakeBlockCommand extends EditorCommand {
  /// Blocks the top-level elements [ids] of scene [scene] into [groupId]
  /// (minted up front via `EditorDocument.nextId`), placed at [transform]
  /// (the members' bounding box, canvas fractions) and arranged as [block].
  const MakeBlockCommand({
    required this.scene,
    required this.ids,
    required this.groupId,
    required this.transform,
    required this.block,
  });

  /// The scene whose elements block.
  final int scene;

  /// The member ids, in z-order.
  final List<String> ids;

  /// The new block group's identity.
  final String groupId;

  /// The group's `transform` JSON (the members' bounding box).
  final Map<String, Object?> transform;

  /// The block kind and parameters to arrange with.
  final BlockSpec block;

  @override
  EditorDocument apply(EditorDocument document) => document
      .groupElements(scene, ids, groupId: groupId, groupTransform: transform)
      .setElementMeta(groupId, {'block': block.toJson()})
      .reflowBlock(groupId);

  @override
  String get label => 'Make ${block.kind.label} block';

  @override
  Set<String> get affectedIds => {groupId, ...ids};
}

/// Rewrites a block's kind or parameters and reflows — also how a plain
/// group becomes a block (the inspector's kind picker).
final class SetBlockParamsCommand extends EditorCommand {
  /// Arranges group [groupId] as [block]. A non-null [mergeGroup] coalesces
  /// a stream of edits (a spinner drag) into one undo step.
  const SetBlockParamsCommand({required this.groupId, required this.block, this.mergeGroup});

  /// The block group being re-parameterized.
  final String groupId;

  /// The new kind and parameters.
  final BlockSpec block;

  /// The coalescing group, or null for a standalone step.
  final String? mergeGroup;

  @override
  EditorDocument apply(EditorDocument document) =>
      document.setElementMeta(groupId, {'block': block.toJson()}).reflowBlock(groupId);

  @override
  String get label => 'Arrange ${block.kind.label} block';

  @override
  Set<String> get affectedIds => {groupId};

  @override
  String? get mergeKey => mergeGroup == null ? null : 'block:$mergeGroup:$groupId';
}

/// Removes the block metadata and nothing else: the Group and every
/// arranged transform stay — a block is sugar over real geometry.
final class ClearBlockCommand extends EditorCommand {
  /// Clears the block metadata of every group in [ids] in one undo step.
  const ClearBlockCommand({required this.ids});

  /// The block group ids being cleared.
  final List<String> ids;

  @override
  EditorDocument apply(EditorDocument document) =>
      ids.fold(document, (current, id) => current.setElementMeta(id, {'block': null}));

  @override
  String get label => 'Clear block';

  @override
  Set<String> get affectedIds => ids.toSet();
}

/// Releases a child dragged out of its block: it leaves the group (id
/// kept), lands right above it at the dragged position, and the block
/// re-balances the remainder — one undo step.
final class ReleaseFromBlockCommand extends EditorCommand {
  /// Releases [childId] from block group [groupId] at the dragged
  /// group-relative placement [transform].
  const ReleaseFromBlockCommand({
    required this.groupId,
    required this.childId,
    required this.transform,
  });

  /// The block group being left.
  final String groupId;

  /// The child being released.
  final String childId;

  /// The dragged placement, in fractions of the group's box (the command
  /// rewrites it to the holding frame through the ungroup promotion math).
  final Map<String, Object?> transform;

  @override
  EditorDocument apply(EditorDocument document) => document.releaseFromBlock(
    groupId: groupId,
    childId: childId,
    relativeTransform: transform,
  );

  @override
  String get label => 'Release $childId';

  @override
  Set<String> get affectedIds => {groupId, childId};
}
