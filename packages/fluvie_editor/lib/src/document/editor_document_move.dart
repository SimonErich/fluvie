part of 'editor_document.dart';

/// Moving one element across a group boundary — the layers panel's drag
/// into and out of a group. Both directions are pure frame rewrites through
/// the 5.3 group math, so nothing moves on screen, and every touched block
/// group re-balances through the reflow choke point.
extension EditorDocumentMove on EditorDocument {
  /// Moves element [id] into the top-level group [groupId] at child
  /// z-position [at] (clamped to the child list).
  ///
  /// The transform rewrites from the slide frame into the group's box
  /// (rotation composed out through the inverse of the ungroup math), so
  /// the element keeps its canvas pixels. The source may be the slide's top
  /// level or another top-level group's children; a Group itself never
  /// moves in — one-level nesting stays the canvas's rule. Throws an
  /// [ArgumentError] for a non-group target, a group source, an element
  /// already inside [groupId], or a cross-scene move.
  EditorDocument moveIntoGroup(String id, {required String groupId, required int at}) {
    final sourceParent = parentGroupOf(id);
    if (elementJson(groupId)?['type'] != 'Group' || parentGroupOf(groupId) != null) {
      throw ArgumentError.value(groupId, 'groupId', 'Only top-level groups take drops');
    }
    if (elementJson(id)?['type'] == 'Group') {
      throw ArgumentError.value(id, 'id', 'Groups never nest by move');
    }
    if (sourceParent == groupId) {
      throw ArgumentError.value(id, 'id', 'Already a child of $groupId; reorder instead');
    }
    final sourceScene = sceneOfElement(sourceParent ?? id);
    if (sourceScene == null || sourceScene != sceneOfElement(groupId)) {
      throw ArgumentError.value(id, 'id', 'Moves stay within one scene');
    }
    final next = _mutate((json) {
      final canvas = _canvasSizeOf(json);
      final source = _childrenHolding(json, id);
      final index = source.indexWhere((child) => (child! as Map)['id'] == id);
      final child = source.removeAt(index)! as Map<String, Object?>;
      var absolute = child['transform'];
      if (sourceParent != null) {
        final sourceGroup = _elementIn(json, sourceParent);
        absolute = absolutePlacementJson(
          absolute,
          groupRectIn(sourceGroup['transform'], canvas),
          canvas,
          groupRotation: _rotationOf(sourceGroup['transform']),
        );
      }
      final target = _elementIn(json, groupId);
      child['transform'] = relativePlacementJson(
        absolute,
        groupRectIn(target['transform'], canvas),
        canvas,
        groupRotation: _rotationOf(target['transform']),
      );
      final children = (target['children'] ??= <Object?>[]) as List<Object?>;
      children.insert(at.clamp(0, children.length), child);
    });
    return next.reflowBlock(sourceParent).reflowBlock(groupId);
  }

  /// Moves the top-level element [id] to scene [toScene] — the video
  /// timeline's cross-scene lane drag. The element's JSON travels verbatim
  /// (id, transform, props, animations, a group's whole subtree), appended
  /// on top of the target's z-order; only its `show` window rewrites, to
  /// `fromFrames..toFrames` relative to the new scene. The id leaves the
  /// source scene's `steps` (a step names its own scene's children);
  /// emptied steps drop, and an emptied list removes the key. Throws an
  /// [ArgumentError] for a group child (it moves with its group), a
  /// same-scene target, an unknown id, or a fill.
  EditorDocument moveElementToScene(
    String id, {
    required int toScene,
    required int fromFrames,
    required int toFrames,
  }) {
    if (parentGroupOf(id) != null) {
      throw ArgumentError.value(id, 'id', 'A grouped element moves with its group');
    }
    final fromScene = sceneOfElement(id);
    if (fromScene == null) {
      throw ArgumentError.value(id, 'id', 'No element with this id');
    }
    if (fromScene == toScene) {
      throw ArgumentError.value(toScene, 'toScene', 'Already there; window the element instead');
    }
    return _mutate((json) {
      final source = _sceneChildren(json, fromScene);
      final index = source.indexWhere((child) => (child! as Map)['id'] == id);
      if (index < 0) {
        throw ArgumentError.value(id, 'id', 'Only scene children move between slides');
      }
      final element = source.removeAt(index)! as Map<String, Object?>;
      element['show'] = {'from': '${fromFrames}f', 'to': '${toFrames}f'};
      _stripFromSteps((json['scenes']! as List<Object?>)[fromScene]! as Map<String, Object?>, id);
      _sceneChildren(json, toScene).add(element);
    });
  }

  /// Moves the group child [id] out to the slide's top level at z-position
  /// [at] (clamped) — the ungroup promotion math for a single element, id
  /// kept, block remainder re-balanced. Throws an [ArgumentError] when [id]
  /// is not a group child.
  EditorDocument moveOutOfGroup(String id, {required int at}) {
    final parent = parentGroupOf(id);
    if (parent == null) {
      throw ArgumentError.value(id, 'id', 'Not a group child');
    }
    final next = _mutate((json) {
      final canvas = _canvasSizeOf(json);
      final group = _elementIn(json, parent);
      final children = group['children']! as List<Object?>;
      final index = children.indexWhere((child) => (child! as Map)['id'] == id);
      final child = children.removeAt(index)! as Map<String, Object?>;
      child['transform'] = absolutePlacementJson(
        child['transform'],
        groupRectIn(group['transform'], canvas),
        canvas,
        groupRotation: _rotationOf(group['transform']),
      );
      final holding = _childrenHolding(json, parent);
      holding.insert(at.clamp(0, holding.length), child);
    });
    return next.reflowBlock(parent);
  }
}

/// Strips [id] from [scene]'s `steps`: emptied steps drop (a step needs a
/// non-empty elements list), and an emptied steps list removes the key.
void _stripFromSteps(Map<String, Object?> scene, String id) {
  final steps = scene['steps'];
  if (steps is! List<Object?>) return;
  for (final step in steps.whereType<Map<String, Object?>>()) {
    final elements = step['elements'];
    if (elements is List) elements.remove(id);
  }
  steps.removeWhere(
    (step) => step is Map<String, Object?> && (step['elements'] as List?)?.isEmpty == true,
  );
  if (steps.isEmpty) scene.remove('steps');
}

/// The mutable element JSON of [id] inside a working copy.
Map<String, Object?> _elementIn(Map<String, Object?> json, String id) {
  final holding = _childrenHolding(json, id);
  return holding.firstWhere((child) => (child! as Map)['id'] == id)! as Map<String, Object?>;
}
