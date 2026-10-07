part of 'editor_document.dart';

/// The document's typed mutations. Every method deep-copies, applies one
/// change, revalidates through the spec parser, and returns a new document —
/// the substrate commands and undo build on.
extension EditorDocumentMutations on EditorDocument {
  /// Replaces the element [id] with [element], keeping the id even when the
  /// patch omits it.
  EditorDocument replaceElement(String id, Map<String, Object?> element) =>
      _mutate((json) => _withElement(json, id, (_) => {..._deepCopy(element), 'id': id}));

  /// Sets (or replaces) the element's `transform`. A child of a block group
  /// re-balances its block afterwards (the block invariant).
  EditorDocument setTransform(String id, Map<String, Object?> transform) => _mutate(
    (json) => _withElement(json, id, (el) => {...el, 'transform': _deepCopy(transform)}),
  ).reflowBlock(parentGroupOf(id));

  /// Inserts [element] into scene [scene] (appended, or at [at]), minting an
  /// id when the JSON carries none. Returns the new document and the id.
  (EditorDocument, String) insertElement(int scene, Map<String, Object?> element, {int? at}) {
    final json = toJson();
    final copy = _deepCopy(element);
    final id = (copy['id'] ??= _nextId(json)) as String;
    final children = _sceneChildren(json, scene);
    children.insert(at ?? children.length, copy);
    return (EditorDocument._(json), id);
  }

  /// Appends [element] to the children of group [groupId] (minting an id
  /// when the JSON carries none) — the paste-into-an-entered-group payload.
  /// The transform is taken verbatim as fractions of the group's box; the
  /// caller re-balances a block target once per batch ([reflowBlock]).
  /// Returns the new document and the id. Throws an [ArgumentError] when
  /// [groupId] is not a group.
  (EditorDocument, String) insertElementInGroup(String groupId, Map<String, Object?> element) {
    final json = toJson();
    final copy = _deepCopy(element);
    final id = (copy['id'] ??= _nextId(json)) as String;
    final group = _elementIn(json, groupId);
    if (group['type'] != 'Group') {
      throw ArgumentError.value(groupId, 'groupId', 'Only groups take children');
    }
    ((group['children'] ??= <Object?>[]) as List<Object?>).add(copy);
    return (EditorDocument._(json), id);
  }

  /// Removes the element [id] — a scene child at any depth, or a fill
  /// (unfilling its slot). A removed group takes its block metadata with it
  /// (a later re-mint of the id must not resurrect an arrangement), and a
  /// block that loses a child re-balances. Throws an [ArgumentError] for an
  /// unknown id.
  EditorDocument removeElement(String id) {
    final parent = parentGroupOf(id);
    return _mutate((json) {
      final held = _fillHolding(json, id);
      if (held != null) {
        held.fills.remove(held.slot);
        if (held.fills.isEmpty) held.scene.remove('fills');
        return;
      }
      final children = _childrenHolding(json, id);
      final index = children.indexWhere((child) => (child! as Map)['id'] == id);
      _dropBlockMetaIn(json, children[index]! as Map<String, Object?>);
      children.removeAt(index);
      // Remove incident transitions, including those inside a deleted group.
      for (final scene in (json['scenes']! as List<Object?>).cast<Map<String, Object?>>()) {
        final present = <String>{};
        void collect(List<Object?> items) {
          for (final item in items.cast<Map<String, Object?>>()) {
            if (item['id'] case final String childId) present.add(childId);
            if (item['children'] case final List<Object?> nested) collect(nested);
          }
        }

        collect((scene['children'] as List<Object?>?) ?? const []);
        final transitions = scene['transitions'];
        if (transitions is List<Object?>) {
          transitions.removeWhere(
            (edge) => ((edge! as Map<String, Object?>)['between']! as List<Object?>).any(
              (id) => !present.contains(id),
            ),
          );
          if (transitions.isEmpty) scene.remove('transitions');
        }
      }
    }).reflowBlock(parent);
  }

  /// Moves the element [id] to z-position [to] within its holding list. A
  /// block group re-balances afterwards (slots follow child order).
  EditorDocument reorderElement(String id, {required int to}) => _mutate((json) {
    final children = _childrenHolding(json, id);
    final index = children.indexWhere((child) => (child! as Map)['id'] == id);
    final element = children.removeAt(index);
    children.insert(to, element);
  }).reflowBlock(parentGroupOf(id));

  EditorDocument _mutate(void Function(Map<String, Object?> json) change) {
    final json = toJson();
    change(json);
    return EditorDocument._(json);
  }
}

/// The mutable children list of scene [index] inside a working copy.
List<Object?> _sceneChildren(Map<String, Object?> json, int index) {
  final scene = (json['scenes']! as List<Object?>)[index]! as Map<String, Object?>;
  return (scene['children'] ??= <Object?>[]) as List<Object?>;
}

/// The mutable children list holding element [id] inside a working copy —
/// the scene's top level, or a group's children list at any depth. Throws
/// an [ArgumentError] when no scene holds it.
List<Object?> _childrenHolding(Map<String, Object?> json, String id) {
  final scenes = json['scenes']! as List<Object?>;
  for (var s = 0; s < scenes.length; s++) {
    final found = _holdingIn(_sceneChildren(json, s), id);
    if (found != null) return found;
  }
  final overlays = json['overlays'];
  if (overlays is List) {
    final found = _holdingIn(overlays, id);
    if (found != null) return found;
  }
  throw ArgumentError.value(id, 'id', 'No element with this id');
}

/// Applies [change] to the element [id] inside a fresh copy of [json] — a
/// scene child at any depth, or a fill (fills are scene-owned elements).
/// Throws an [ArgumentError] when no scene holds it.
Map<String, Object?> _withElement(
  Map<String, Object?> json,
  String id,
  Map<String, Object?> Function(Map<String, Object?> element) change,
) {
  final held = _fillHolding(json, id);
  if (held != null) {
    held.fills[held.slot] = change(held.fills[held.slot]! as Map<String, Object?>);
    return json;
  }
  final children = _childrenHolding(json, id);
  final index = children.indexWhere((child) => (child! as Map)['id'] == id);
  children[index] = change(children[index]! as Map<String, Object?>);
  return json;
}
