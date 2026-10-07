import 'package:fluvie_editor/src/document/editor_document.dart';

/// A copy of a template's [scene] ready to insert into [document]: every
/// element without an `id` — top-level children, nested group children, and
/// slot fills — gets one minted against the document, so the insert command
/// can carry its ids up front (undo and redo always see the same elements).
Map<String, Object?> preparedTemplateScene(EditorDocument document, Map<String, Object?> scene) {
  final prepared = {...scene};
  final missing = <Map<String, Object?>>[];
  void walk(Map<String, Object?> element) {
    if (element['id'] is! String) missing.add(element);
    final children = element['children'];
    if (element['type'] == 'Group' && children is List) {
      children.whereType<Map<String, Object?>>().forEach(walk);
    }
  }

  final children = scene['children'];
  final copiedChildren = children is List
      ? [
          for (final child in children)
            if (child is Map<String, Object?>) _deepCopyMap(child) else child,
        ]
      : null;
  if (copiedChildren != null) {
    prepared['children'] = copiedChildren;
    copiedChildren.whereType<Map<String, Object?>>().forEach(walk);
  }
  final fills = scene['fills'];
  if (fills is Map<String, Object?>) {
    final copiedFills = {
      for (final entry in fills.entries)
        entry.key: entry.value is Map<String, Object?>
            ? _deepCopyMap(entry.value! as Map<String, Object?>)
            : entry.value,
    };
    prepared['fills'] = copiedFills;
    copiedFills.values.whereType<Map<String, Object?>>().forEach(walk);
  }
  final ids = document.nextIds(missing.length).iterator;
  for (final element in missing) {
    element['id'] = (ids..moveNext()).current;
  }
  return prepared;
}

/// [deckTheme] with [templateTheme]'s tokens merged additively: existing
/// deck entries always win, missing palette, type scale, and spacing tokens
/// arrive from the template, and the template's motion applies only when
/// the deck declares none. Null when both sides are null.
Map<String, Object?>? mergedThemeJson(
  Map<String, Object?>? deckTheme,
  Map<String, Object?>? templateTheme,
) {
  if (templateTheme == null) return deckTheme;
  if (deckTheme == null) return _deepCopyMap(templateTheme);
  final merged = {...deckTheme};
  for (final map in const ['palette', 'typeScale', 'spacing']) {
    final incoming = templateTheme[map];
    if (incoming is! Map<String, Object?>) continue;
    final existing = deckTheme[map];
    merged[map] = {
      ..._deepCopyMap(incoming),
      if (existing is Map<String, Object?>) ...existing,
    };
  }
  if (merged['motion'] == null && templateTheme['motion'] != null) {
    merged['motion'] = templateTheme['motion'];
  }
  return merged;
}

/// [deckMasters] with [templateMasters] merged additively: a name the deck
/// already defines keeps the deck's master, new names arrive from the
/// template. Null when both sides are null.
Map<String, Object?>? mergedMastersJson(
  Map<String, Object?>? deckMasters,
  Map<String, Object?>? templateMasters,
) {
  if (templateMasters == null) return deckMasters;
  if (deckMasters == null) return _deepCopyMap(templateMasters);
  return {
    ...deckMasters,
    for (final entry in templateMasters.entries)
      if (!deckMasters.containsKey(entry.key)) entry.key: entry.value,
  };
}

Map<String, Object?> _deepCopyMap(Map<String, Object?> json) => {
  for (final entry in json.entries) entry.key: _copy(entry.value),
};

Object? _copy(Object? value) => switch (value) {
  Map<String, Object?>() => _deepCopyMap(value),
  List<Object?>() => [for (final item in value) _copy(item)],
  _ => value,
};
