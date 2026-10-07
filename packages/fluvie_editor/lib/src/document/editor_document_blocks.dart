part of 'editor_document.dart';

/// The smart-block reads and mutations. A block is editor metadata on a
/// spec `Group` (`editor.elements.<groupId>.block`); its children always
/// hold real spec transforms, so clearing the block or opening the file
/// elsewhere loses nothing.
extension EditorDocumentBlocks on EditorDocument {
  /// The block arranged on group [id], or null when [id] is not a group or
  /// carries no (readable) block metadata.
  BlockSpec? blockOf(String id) {
    if (elementJson(id)?['type'] != 'Group') return null;
    return BlockSpec.fromJson(elementMeta(id)['block']);
  }

  /// Re-arranges the children of block group [groupId] from its parameters,
  /// writing their group-relative transforms. A null id or a non-block
  /// returns this document unchanged, so mutation paths call it
  /// unconditionally.
  EditorDocument reflowBlock(String? groupId) {
    if (groupId == null) return this;
    final block = blockOf(groupId);
    if (block == null) return this;
    return _mutate((json) {
      final scenes = json['scenes']! as List<Object?>;
      for (final scene in scenes.whereType<Map<String, Object?>>()) {
        for (final walked in _walkScene(scene)) {
          if (walked.element['id'] != groupId) continue;
          _applyReflow(walked.element, block);
          return;
        }
      }
    });
  }

  /// Releases [childId] from block group [groupId]: the child leaves the
  /// group and lands in the group's holding list right above it, its
  /// dragged group-relative [relativeTransform] rewritten to the holding
  /// frame through the ungroup promotion math (id kept), and the block
  /// re-balances the remainder. Throws an [ArgumentError] when [childId] is
  /// not a child of the group.
  EditorDocument releaseFromBlock({
    required String groupId,
    required String childId,
    required Map<String, Object?> relativeTransform,
  }) {
    final block = blockOf(groupId);
    return _mutate((json) {
      final holding = _childrenHolding(json, groupId);
      final index = holding.indexWhere((child) => (child! as Map)['id'] == groupId);
      final group = holding[index]! as Map<String, Object?>;
      final children = group['children'];
      if (children is! List<Object?>) {
        throw ArgumentError.value(groupId, 'groupId', 'Not a group with children');
      }
      final childIndex = children.indexWhere((child) => (child! as Map)['id'] == childId);
      if (childIndex < 0) {
        throw ArgumentError.value(childId, 'childId', 'Not a child of $groupId');
      }
      final frame = _frameSizeHolding(json, groupId);
      final groupRect = groupRectIn(group['transform'], frame);
      final child = children.removeAt(childIndex)! as Map<String, Object?>;
      child['transform'] = absolutePlacementJson(
        relativeTransform,
        groupRect,
        frame,
        groupRotation: _rotationOf(group['transform']),
      );
      holding.insert(index + 1, child);
      if (block != null) _applyReflow(group, block);
    });
  }
}

/// Writes the reflowed transforms onto [group]'s children in place.
void _applyReflow(Map<String, Object?> group, BlockSpec block) {
  final children = _groupChildren(group);
  final transforms = reflowedBlockTransforms(block, children);
  for (final child in children) {
    final next = transforms[child['id']];
    if (next != null) child['transform'] = next;
  }
}

/// Drops the `block` metadata of [element] and of every group nested in it
/// — called when the subtree leaves the document, so a re-minted id never
/// inherits a stale arrangement.
void _dropBlockMetaIn(Map<String, Object?> json, Map<String, Object?> element) {
  if (element['type'] != 'Group') return;
  _dropBlockMetaOf(json, element['id']);
  for (final child in _groupChildren(element)) {
    _dropBlockMetaIn(json, child);
  }
}

/// Drops the `block` key of [id]'s editor metadata (and the empty entry it
/// may leave behind).
void _dropBlockMetaOf(Map<String, Object?> json, Object? id) {
  final editor = json['editor'];
  if (editor is! Map<String, Object?>) return;
  final elements = editor['elements'];
  if (elements is! Map<String, Object?>) return;
  final meta = elements[id];
  if (meta is! Map<String, Object?>) return;
  meta.remove('block');
  if (meta.isEmpty) elements.remove(id);
}
