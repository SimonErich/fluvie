part of 'editor_document.dart';

// The fill and placeholder JSON walkers behind `EditorDocumentMasters`:
// slot resolution, orphan promotion, and the lookup that lets the element
// mutations reach fills (they are scene-owned elements).

MasterSlot _slotOf(Map<String, Object?> placeholder, Map<String, Object?> fills) {
  final slot = placeholder['slot']! as String;
  final fill = fills[slot];
  final fillMap = fill is Map<String, Object?> ? fill : null;
  final transform = fillMap?['transform'] ?? placeholder['transform'];
  final style = placeholder['style'];
  return (
    slot: slot,
    fillId: fillMap?['id'] as String?,
    transform: transform is Map<String, Object?> ? _deepCopy(transform) : null,
    style: style is Map<String, Object?> ? _deepCopy(style) : null,
  );
}

Map<String, Object?>? _masterIn(Map<String, Object?> json, String name) {
  final masters = json['masters'];
  final master = masters is Map<String, Object?> ? masters[name] : null;
  return master is Map<String, Object?> ? master : null;
}

Map<String, Object?> _sceneIn(Map<String, Object?> json, int index) =>
    (json['scenes']! as List<Object?>)[index]! as Map<String, Object?>;

/// The placeholder children of a master's JSON, in order.
List<Map<String, Object?>> _placeholdersOf(Map<String, Object?> master) {
  final children = master['children'];
  if (children is! List) return const [];
  return [
    for (final child in children.whereType<Map<String, Object?>>())
      if (child['type'] == 'Placeholder') child,
  ];
}

/// The placeholders of the master named by [name] in [json], by slot.
Map<String, Map<String, Object?>> _placeholdersBySlot(Map<String, Object?> json, Object? name) {
  final master = name is String ? _masterIn(json, name) : null;
  return {
    if (master != null)
      for (final placeholder in _placeholdersOf(master))
        placeholder['slot']! as String: placeholder,
  };
}

/// Appends [fill] to [scene]'s children as a plain element carrying its
/// resolved look: its own transform (else [placeholder]'s, else centered),
/// the placeholder style merged under its own per field.
void _promoteFill(Map<String, Object?> scene, Object? fill, Map<String, Object?>? placeholder) {
  if (fill is! Map<String, Object?>) return;
  final promoted = _deepCopy(fill);
  final fallback = placeholder?['transform'];
  promoted['transform'] ??= fallback is Map<String, Object?>
      ? _deepCopy(fallback)
      : <String, Object?>{'x': 0.5, 'y': 0.5};
  final defaults = placeholder?['style'];
  if (defaults is Map<String, Object?>) {
    final own = promoted['style'];
    promoted['style'] = {..._deepCopy(defaults), if (own is Map<String, Object?>) ...own};
  }
  ((scene['children'] ??= <Object?>[]) as List<Object?>).add(promoted);
}

/// The fills map (and its scene) holding the fill with [id], or null.
({Map<String, Object?> scene, Map<String, Object?> fills, String slot})? _fillHolding(
  Map<String, Object?> json,
  String id,
) {
  final scenes = json['scenes'];
  if (scenes is! List) return null;
  for (final scene in scenes.whereType<Map<String, Object?>>()) {
    final fills = scene['fills'];
    if (fills is! Map<String, Object?>) continue;
    for (final entry in fills.entries) {
      final fill = entry.value;
      if (fill is Map<String, Object?> && fill['id'] == id) {
        return (scene: scene, fills: fills, slot: entry.key);
      }
    }
  }
  return null;
}
