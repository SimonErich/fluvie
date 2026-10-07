import 'dart:convert' show jsonDecode, jsonEncode;

/// Deep-copies a copied element set and re-mints its identities for a paste.
///
/// Every element — nested group children included — gets a fresh id from
/// [mintId], in depth-first document order. Anchor ids *declared* within the
/// set are remapped through [mintAnchorId] and every in-set reference to
/// them (a trigger's `anchor`, a beat's `track`) follows consistently;
/// references to anchors declared outside the set are preserved verbatim.
/// The input elements are never touched.
List<Map<String, Object?>> remintedElements(
  List<Map<String, Object?>> elements, {
  required String Function() mintId,
  required String Function(String old) mintAnchorId,
}) {
  final copies = [
    for (final element in elements) jsonDecode(jsonEncode(element)) as Map<String, Object?>,
  ];
  final all = <Map<String, Object?>>[];
  void walk(Map<String, Object?> element) {
    all.add(element);
    final children = element['children'];
    if (element['type'] == 'Group' && children is List) {
      children.whereType<Map<String, Object?>>().forEach(walk);
    }
  }

  copies.forEach(walk);

  final anchorMap = <String, String>{
    for (final element in all)
      if (element['anchor'] case final String declared) declared: '',
  };
  for (final declared in anchorMap.keys) {
    anchorMap[declared] = mintAnchorId(declared);
  }

  for (final element in all) {
    element['id'] = mintId();
    if (element['anchor'] case final String declared) {
      element['anchor'] = anchorMap[declared];
    }
    _remapTriggerRefs(element, anchorMap);
  }
  return copies;
}

/// Rewrites the anchor references inside one element's `animate` list for
/// every anchor the set re-minted.
void _remapTriggerRefs(Map<String, Object?> element, Map<String, String> anchorMap) {
  final animate = element['animate'];
  if (animate is! List) return;
  for (final spec in animate.whereType<Map<String, Object?>>()) {
    final at = spec['at'];
    if (at is! Map<String, Object?>) continue;
    for (final key in const ['anchor', 'track']) {
      final reference = at[key];
      if (reference is String && anchorMap.containsKey(reference)) {
        at[key] = anchorMap[reference];
      }
    }
  }
}
