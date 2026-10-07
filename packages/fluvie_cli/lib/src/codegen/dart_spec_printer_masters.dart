part of 'dart_spec_printer.dart';

// The printer's half of masters. Printed Dart is the render — no master
// object exists at the widget layer — so every adopting scene prints
// RESOLVED, mirroring fluvie's `resolveSceneMaster` over JSON: the master
// background unless the scene declares its own, the master children with
// each placeholder replaced by its fill (a fill's transform beats the
// placeholder's; the placeholder style merges under the fill's per field),
// then the scene's own children. The printed file leads with one comment
// per applied master.

/// The document with every adopting scene resolved, plus the distinct
/// master names applied, in scene order.
typedef _ResolvedMasters = ({Map<String, Object?> spec, List<String> applied});

/// Resolves the `masters` block into the scenes and strips it: the returned
/// spec is fully freeform, ready for the plain printer path. Unresolvable
/// adoption throws a [FormatException], the printer's loud-failure rule.
_ResolvedMasters _applyMasters(Map<String, Object?> spec) {
  final mastersRaw = spec['masters'];
  final masters = mastersRaw is Map<String, Object?> ? mastersRaw : const <String, Object?>{};
  final scenes = spec['scenes'];
  if (scenes is! List) return (spec: spec, applied: const []);
  final applied = <String>[];
  final resolved = <Object?>[];
  for (final scene in scenes) {
    if (scene is! Map<String, Object?> || (scene['master'] == null && scene['fills'] == null)) {
      resolved.add(scene);
      continue;
    }
    final name = scene['master'];
    if (name is! String) {
      throw const FormatException('"fills" need a "master" to fill');
    }
    final master = masters[name];
    if (master is! Map<String, Object?>) {
      throw FormatException('Unknown master "$name"; the document has no such master');
    }
    if (!applied.contains(name)) applied.add(name);
    resolved.add(_resolveScene(scene, name, master));
  }
  final stripped = {...spec, 'scenes': resolved}..remove('masters');
  return (spec: stripped, applied: applied);
}

Map<String, Object?> _resolveScene(
  Map<String, Object?> scene,
  String name,
  Map<String, Object?> master,
) {
  final fillsRaw = scene['fills'];
  final fills = fillsRaw is Map<String, Object?> ? fillsRaw : const <String, Object?>{};
  final children = <Object?>[];
  final slots = <String>{};
  final masterChildren = master['children'];
  if (masterChildren is List) {
    for (final child in masterChildren) {
      if (child is! Map<String, Object?>) continue;
      if (child['type'] != 'Placeholder') {
        children.add(child);
        continue;
      }
      final slot = child['slot'];
      if (slot is! String) continue;
      slots.add(slot);
      final fill = fills[slot];
      if (fill is Map<String, Object?>) children.add(_filledElement(fill, child));
    }
  }
  for (final slot in fills.keys) {
    if (!slots.contains(slot)) {
      throw FormatException('Unknown slot "$slot"; master "$name" does not define it');
    }
  }
  final sceneChildren = scene['children'];
  if (sceneChildren is List) children.addAll(sceneChildren);
  final resolved = {...scene}
    ..remove('master')
    ..remove('fills')
    ..['children'] = children;
  if (scene['background'] == null && master['background'] != null) {
    resolved['background'] = master['background'];
  }
  return resolved;
}

/// The fill with the placeholder's placement and style defaults applied:
/// the fill's own `transform` wins whole, its `style` wins per field, and a
/// non-map fill style passes through untouched — exactly the builder's rule.
Map<String, Object?> _filledElement(
  Map<String, Object?> fill,
  Map<String, Object?> placeholder,
) {
  final merged = {...fill};
  if (fill['transform'] == null && placeholder['transform'] != null) {
    merged['transform'] = placeholder['transform'];
  }
  final defaults = placeholder['style'];
  final own = fill['style'];
  if (defaults is Map<String, Object?> && (own == null || own is Map<String, Object?>)) {
    merged['style'] = {...defaults, ...?(own as Map<String, Object?>?)};
  }
  return merged;
}
