part of 'editor_document.dart';

/// The document's typed mutations. Every method deep-copies, applies one
/// change, revalidates through the spec parser, and returns a new document —
/// the substrate commands and undo build on.
extension EditorDocumentMutations on EditorDocument {
  /// Replaces the element [id] with [element], keeping the id even when the
  /// patch omits it.
  EditorDocument replaceElement(String id, Map<String, Object?> element) =>
      _mutate((json) => _withElement(json, id, (_) => {..._deepCopy(element), 'id': id}));

  /// Sets (or replaces) the element's `transform`.
  EditorDocument setTransform(String id, Map<String, Object?> transform) =>
      _mutate((json) => _withElement(json, id, (el) => {...el, 'transform': _deepCopy(transform)}));

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

  /// Removes the element [id]. Throws an [ArgumentError] for an unknown id.
  EditorDocument removeElement(String id) => _mutate(
    (json) => _childrenHolding(json, id).removeWhere((child) => (child! as Map)['id'] == id),
  );

  /// Moves the element [id] to z-position [to] within its scene.
  EditorDocument reorderElement(String id, {required int to}) => _mutate((json) {
    final children = _childrenHolding(json, id);
    final index = children.indexWhere((child) => (child! as Map)['id'] == id);
    final element = children.removeAt(index);
    children.insert(to, element);
  });

  /// Adds [scene] (appended, or at [at]).
  EditorDocument addScene(Map<String, Object?> scene, {int? at}) => _mutate((json) {
    final scenes = json['scenes']! as List<Object?>;
    scenes.insert(at ?? scenes.length, _deepCopy(scene));
  });

  /// Removes scene [index]. A deck is never empty: removing the last scene
  /// throws a [StateError].
  EditorDocument removeScene(int index) => _mutate((json) {
    final scenes = json['scenes']! as List<Object?>;
    if (scenes.length == 1) {
      throw StateError('A deck needs at least one slide.');
    }
    scenes.removeAt(index);
  });

  /// Moves scene [from] to position [to].
  EditorDocument reorderScene(int from, int to) => _mutate((json) {
    final scenes = json['scenes']! as List<Object?>;
    scenes.insert(to, scenes.removeAt(from));
  });

  /// Writes the editor-block metadata for element [id] (merging over what
  /// was there).
  EditorDocument setElementMeta(String id, Map<String, Object?> meta) => _mutate((json) {
    final editor =
        (json['editor'] ??= <String, Object?>{'editorSchema': 1}) as Map<String, Object?>;
    final elements = (editor['elements'] ??= <String, Object?>{}) as Map<String, Object?>;
    final existing = elements[id];
    elements[id] = {
      if (existing is Map<String, Object?>) ...existing,
      ..._deepCopy(meta),
    };
  });

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

/// The mutable children list holding element [id] inside a working copy.
/// Throws an [ArgumentError] when no scene holds it.
List<Object?> _childrenHolding(Map<String, Object?> json, String id) {
  final scenes = json['scenes']! as List<Object?>;
  for (var s = 0; s < scenes.length; s++) {
    final children = _sceneChildren(json, s);
    if (children.any((child) => (child as Map?)?['id'] == id)) return children;
  }
  throw ArgumentError.value(id, 'id', 'No element with this id');
}

/// Applies [change] to the element [id] inside a fresh copy of [json].
/// Throws an [ArgumentError] when no scene holds it.
Map<String, Object?> _withElement(
  Map<String, Object?> json,
  String id,
  Map<String, Object?> Function(Map<String, Object?> element) change,
) {
  final children = _childrenHolding(json, id);
  final index = children.indexWhere((child) => (child! as Map)['id'] == id);
  children[index] = change(children[index]! as Map<String, Object?>);
  return json;
}
