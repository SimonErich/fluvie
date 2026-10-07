part of 'editor_document.dart';

/// The arrange mutations: group and ungroup, z-order over multi-selections,
/// and the spec `visible` flag. Same substrate as [EditorDocumentMutations]:
/// deep-copy, one change, revalidate, new document.
extension EditorDocumentArrange on EditorDocument {
  /// Wraps the top-level elements [ids] of scene [scene] into a new Group
  /// [groupId] occupying [groupTransform] (the members' bounding box, in
  /// canvas fractions).
  ///
  /// Members keep their ids; their transforms are rewritten relative to the
  /// group's box, so nothing moves on screen. The group takes the topmost
  /// member's z-slot. Throws an [ArgumentError] for fewer than two members
  /// or ids that are not top-level elements of the scene.
  EditorDocument groupElements(
    int scene,
    List<String> ids, {
    required String groupId,
    required Map<String, Object?> groupTransform,
  }) => _mutate((json) {
    final children = _sceneChildren(json, scene);
    final unique = ids.toSet();
    if (unique.length < 2) {
      throw ArgumentError.value(ids, 'ids', 'Grouping needs two or more elements');
    }
    final indices = [
      for (var i = 0; i < children.length; i++)
        if (unique.contains((children[i]! as Map)['id'])) i,
    ];
    if (indices.length != unique.length) {
      throw ArgumentError.value(ids, 'ids', 'Every member must be a top-level scene element');
    }
    final canvas = _canvasSizeOf(json);
    final groupRect = groupRectIn(groupTransform, canvas);
    final members = <Map<String, Object?>>[];
    for (final index in indices) {
      final member = children[index]! as Map<String, Object?>;
      member['transform'] = relativePlacementJson(member['transform'], groupRect, canvas);
      members.add(member);
    }
    final insertAt = indices.last - (indices.length - 1);
    children
      ..removeWhere((child) => unique.contains((child! as Map)['id']))
      ..insert(insertAt, {
        'id': groupId,
        'type': 'Group',
        'transform': _deepCopy(groupTransform),
        'children': members,
      });
  });

  /// Dissolves the group [id]: its children return to the holding list at
  /// the group's z-slot, in their internal order, with transforms rewritten
  /// back to the parent frame — pixel-identical, ids untouched. Throws an
  /// [ArgumentError] when [id] is not a group.
  EditorDocument ungroupElement(String id) => _mutate((json) {
    final holding = _childrenHolding(json, id);
    final index = holding.indexWhere((child) => (child! as Map)['id'] == id);
    final group = holding[index]! as Map<String, Object?>;
    if (group['type'] != 'Group') {
      throw ArgumentError.value(id, 'id', 'Only groups ungroup');
    }
    final frame = _frameSizeHolding(json, id);
    final groupRect = groupRectIn(group['transform'], frame);
    final rotation = _rotationOf(group['transform']);
    final released = [
      for (final child in _groupChildren(group))
        {
          ...child,
          'transform': absolutePlacementJson(
            child['transform'],
            groupRect,
            frame,
            groupRotation: rotation,
          ),
        },
    ];
    holding
      ..removeAt(index)
      ..insertAll(index, released);
    // The group id is gone; stale block meta must not resurrect on a later
    // re-mint of the same id. The released children keep their own metadata.
    _dropBlockMetaOf(json, id);
  });

  /// Applies the z-order move [order] to [ids]. Each holding list (the
  /// scene's top level, or a group's children) rearranges independently;
  /// moved runs keep their relative order. Block groups whose children
  /// moved re-balance (slots follow child order). Throws an [ArgumentError]
  /// for an unknown id.
  EditorDocument arrangeOrder(List<String> ids, ArrangeOrder order) {
    final parents = <String>{
      for (final id in ids)
        if (parentGroupOf(id) case final String parent) parent,
    };
    final next = _mutate((json) {
      final moving = ids.toSet();
      final lists = <List<Object?>>[];
      for (final id in moving) {
        final holding = _childrenHolding(json, id);
        if (!lists.any((list) => identical(list, holding))) lists.add(holding);
      }
      for (final list in lists) {
        final byId = {for (final child in list) (child! as Map)['id']! as String: child};
        final ordered = arrangedIds(byId.keys.toList(), moving, order);
        list
          ..clear()
          ..addAll([for (final id in ordered) byId[id]]);
      }
    });
    return parents.fold(next, (current, parent) => current.reflowBlock(parent));
  }

  /// Writes the element's spec `visible` flag: `false` stores it, `true`
  /// removes the key (the canonical elision). Render-affecting — this moves
  /// the digest, unlike the editor-block lock.
  EditorDocument setElementVisible(String id, {required bool visible}) => _mutate(
    (json) => _withElement(json, id, (element) {
      final next = {...element};
      if (visible) {
        next.remove('visible');
      } else {
        next['visible'] = false;
      }
      return next;
    }),
  );
}

/// The canvas size a document's fractions resolve against.
Size _canvasSizeOf(Map<String, Object?> json) {
  final size = json['size']! as Map<String, Object?>;
  return Size((size['width']! as num).toDouble(), (size['height']! as num).toDouble());
}

/// The pixel size of the frame whose children list holds [id]: the canvas,
/// or the resolved box of the group chain above it.
Size _frameSizeHolding(Map<String, Object?> json, String id) {
  final canvas = _canvasSizeOf(json);
  final scenes = json['scenes']! as List<Object?>;
  for (final scene in scenes.whereType<Map<String, Object?>>()) {
    final found = _frameIn(_children(scene), id, canvas);
    if (found != null) return found;
  }
  // coverage:ignore-start unreachable because ungroupElement resolves the id through _childrenHolding first
  throw ArgumentError.value(id, 'id', 'No element with this id');
  // coverage:ignore-end
}

Size? _frameIn(List<Map<String, Object?>> children, String id, Size frame) {
  for (final child in children) {
    if (child['id'] == id) return frame;
    if (child['type'] != 'Group') continue;
    final rect = groupRectIn(child['transform'], frame);
    final found = _frameIn(_groupChildren(child), id, rect.size);
    if (found != null) return found;
  }
  return null;
}

double _rotationOf(Object? transform) {
  if (transform is! Map<String, Object?>) return 0;
  final rotation = transform['rotation'];
  return rotation is num ? rotation.toDouble() : 0;
}
