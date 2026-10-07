part of 'editor_document.dart';

// Nested traversal: a Group nests a whole children list, so ids live at any
// depth. These walkers are the one place that knows the recursion; lookups,
// minting, and mutations all ride them.

/// One walked element with the id of the group holding it (null at the
/// scene's top level).
typedef _WalkedElement = ({Map<String, Object?> element, String? parent});

/// Every element of [scene], depth-first: each element at its z-position,
/// each group immediately followed by its children — then the master-slot
/// fills, which are scene-owned elements too (they get minted ids, join the
/// id and anchor namespaces, and resolve through lookups; z-order surfaces
/// keep reading `children` directly, so fills stay out of those until the
/// master editing surface lands).
Iterable<_WalkedElement> _walkScene(Map<String, Object?> scene) sync* {
  yield* _walkElements(_children(scene), null);
  final fills = scene['fills'];
  if (fills is! Map<String, Object?>) return;
  for (final fill in fills.values) {
    if (fill is Map<String, Object?>) yield* _walkElements([fill], null);
  }
}

Iterable<_WalkedElement> _walkElements(
  List<Map<String, Object?>> elements,
  String? parent,
) sync* {
  for (final element in elements) {
    yield (element: element, parent: parent);
    if (element['type'] == 'Group') {
      yield* _walkElements(_groupChildren(element), element['id'] as String?);
    }
  }
}

/// The children of a Group element (empty for anything else).
List<Map<String, Object?>> _groupChildren(Map<String, Object?> element) {
  final children = element['children'];
  if (element['type'] != 'Group' || children is! List) return const [];
  return children.cast<Map<String, Object?>>();
}

/// Every element id in [json], nested ones included.
Set<Object?> _usedIds(Map<String, Object?> json) {
  final used = <Object?>{};
  // The overlays share the id namespace: a minted id that collided with one
  // would make two elements answer to the same name.
  for (final walked in _walkElements(_overlayJson(json), null)) {
    used.add(walked.element['id']);
  }
  final scenes = json['scenes'];
  if (scenes is! List) return used;
  for (final scene in scenes.whereType<Map<String, Object?>>()) {
    for (final walked in _walkScene(scene)) {
      used.add(walked.element['id']);
    }
  }
  return used;
}

void _mintMissingIds(Map<String, Object?> json) {
  final used = _usedIds(json);
  for (final walked in _walkElements(_overlayJson(json), null)) {
    walked.element['id'] ??= _mintId(used);
  }
  final scenes = json['scenes'];
  if (scenes is! List) return;
  for (final scene in scenes.whereType<Map<String, Object?>>()) {
    for (final walked in _walkScene(scene)) {
      walked.element['id'] ??= _mintId(used);
    }
  }
}

String _nextId(Map<String, Object?> json) => _mintId(_usedIds(json));

/// Mints the lowest free `el-N` id and marks it used.
String _mintId(Set<Object?> used) {
  var counter = 1;
  while (used.contains('el-$counter')) {
    counter++;
  }
  final id = 'el-$counter';
  used.add(id);
  return id;
}

/// The mutable children list (of [children] or a nested group) holding
/// element [id], or null when none does.
List<Object?>? _holdingIn(List<Object?> children, String id) {
  if (children.any((child) => (child as Map?)?['id'] == id)) return children;
  for (final child in children.whereType<Map<String, Object?>>()) {
    if (child['type'] != 'Group') continue;
    final nested = child['children'];
    if (nested is! List<Object?>) continue;
    final found = _holdingIn(nested, id);
    if (found != null) return found;
  }
  return null;
}

/// Phase-3 documents stored hide as editor-block metadata; the spec's
/// `visible` flag is the render-affecting truth now, so loading migrates:
/// `hidden: true` writes `visible: false` on the element and the meta key
/// disappears either way.
void _migrateHiddenMeta(Map<String, Object?> json) {
  final editor = json['editor'];
  if (editor is! Map<String, Object?>) return;
  final elements = editor['elements'];
  if (elements is! Map<String, Object?>) return;
  for (final id in [...elements.keys]) {
    final meta = elements[id];
    if (meta is! Map<String, Object?> || !meta.containsKey('hidden')) continue;
    final hidden = meta.remove('hidden');
    if (meta.isEmpty) elements.remove(id);
    if (hidden != true) continue;
    final scenes = json['scenes'];
    if (scenes is! List) continue;
    for (final scene in scenes.whereType<Map<String, Object?>>()) {
      for (final walked in _walkScene(scene)) {
        if (walked.element['id'] == id) walked.element['visible'] = false;
      }
    }
  }
}
